import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

type CommentRecord = {
  id: string;
  moment_id: string;
  author_id: string;
  parent_id: string | null;
  body: string;
};

type WebhookPayload = {
  type: "INSERT";
  table: "moment_comments";
  schema: "public";
  record: CommentRecord;
};

type FirebaseServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const webhookSecret = Deno.env.get("COMMENT_PUSH_WEBHOOK_SECRET")!;
const firebaseServiceAccountJson = Deno.env.get(
  "FIREBASE_SERVICE_ACCOUNT_JSON",
);
const firebaseServiceAccountJsonBase64 = Deno.env.get(
  "FIREBASE_SERVICE_ACCOUNT_JSON_BASE64",
);

const supabase = createClient(supabaseUrl, serviceRoleKey);

Deno.serve(async (req) => {
  try {
    if (req.headers.get("x-webhook-secret") !== webhookSecret) {
      return new Response("Unauthorized", { status: 401 });
    }

    const payload = await req.json() as WebhookPayload;
    console.log("send-comment-push payload", {
      type: payload.type,
      table: payload.table,
      hasRecord: payload.record !== undefined,
      commentId: payload.record?.id,
      momentId: payload.record?.moment_id,
    });

    const comment = payload.record;
    if (!comment) {
      return Response.json(
        { error: "Webhook payload does not include record." },
        { status: 400 },
      );
    }

    const recipientUserId = await findRecipientUserId(comment);
    console.log("send-comment-push recipient", {
      recipientUserId,
      authorId: comment.author_id,
    });

    if (recipientUserId === null || recipientUserId === comment.author_id) {
      return Response.json({ sent: 0, reason: "no-recipient" });
    }

    const { data: tokens, error } = await supabase
      .from("push_tokens")
      .select("token")
      .eq("user_id", recipientUserId);

    if (error) {
      throw error;
    }

    if (!tokens || tokens.length === 0) {
      return Response.json({ sent: 0, reason: "no-tokens" });
    }

    console.log("send-comment-push tokens", { count: tokens.length });

    const accessToken = await getFirebaseAccessToken();
    const title = comment.parent_id === null ? "New comment" : "New reply";
    const body = trimNotificationBody(comment.body);

    const results = await Promise.allSettled(
      tokens.map(({ token }) =>
        sendFcmMessage({
          accessToken,
          token,
          title,
          body,
          data: {
            type: comment.parent_id === null
              ? "moment_comment"
              : "moment_reply",
            moment_id: comment.moment_id,
            comment_id: comment.id,
          },
        })
      ),
    );

    const failed = results.filter((result) => result.status === "rejected");
    for (const failure of failed) {
      console.error("send-comment-push FCM failure", failure.reason);
    }

    return Response.json({
      sent: results.filter((result) => result.status === "fulfilled").length,
      failed: failed.length,
    });
  } catch (error) {
    console.error("send-comment-push failed", error);
    return Response.json(
      {
        error: error instanceof Error ? error.message : String(error),
      },
      { status: 500 },
    );
  }
});

async function findRecipientUserId(
  comment: CommentRecord,
): Promise<string | null> {
  if (comment.parent_id !== null) {
    const { data: parent, error } = await supabase
      .from("moment_comments")
      .select("author_id")
      .eq("id", comment.parent_id)
      .single();

    if (error) {
      throw error;
    }

    return parent.author_id as string;
  }

  const { data: moment, error } = await supabase
    .from("moments")
    .select("author_id")
    .eq("id", comment.moment_id)
    .single();

  if (error) {
    throw error;
  }

  return moment.author_id as string;
}

function trimNotificationBody(body: string): string {
  const trimmed = body.trim();
  if (trimmed.length <= 120) {
    return trimmed;
  }

  return `${trimmed.substring(0, 117)}...`;
}

async function getFirebaseAccessToken(): Promise<string> {
  const firebaseServiceAccount = getFirebaseServiceAccount();
  const now = Math.floor(Date.now() / 1000);
  const key = await importPrivateKey(firebaseServiceAccount.private_key);
  const assertion = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: firebaseServiceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: getNumericDate(60 * 60),
    },
    key,
  );

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(await response.text());
  }

  const json = await response.json() as { access_token: string };
  return json.access_token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll("\\n", "")
    .replaceAll("\n", "")
    .trim();
  const binary = Uint8Array.from(atob(base64), (char) => char.charCodeAt(0));

  return crypto.subtle.importKey(
    "pkcs8",
    binary,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
}

async function sendFcmMessage({
  accessToken,
  token,
  title,
  body,
  data,
}: {
  accessToken: string;
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}) {
  const firebaseServiceAccount = getFirebaseServiceAccount();
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${firebaseServiceAccount.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title,
            body,
          },
          data,
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(await response.text());
  }
}

function getFirebaseServiceAccount(): FirebaseServiceAccount {
  if (firebaseServiceAccountJsonBase64) {
    const json = new TextDecoder().decode(
      Uint8Array.from(atob(firebaseServiceAccountJsonBase64), (char) =>
        char.charCodeAt(0)
      ),
    );
    return JSON.parse(json) as FirebaseServiceAccount;
  }

  if (firebaseServiceAccountJson) {
    return JSON.parse(firebaseServiceAccountJson) as FirebaseServiceAccount;
  }

  throw new Error(
    "Missing FIREBASE_SERVICE_ACCOUNT_JSON_BASE64 or FIREBASE_SERVICE_ACCOUNT_JSON secret.",
  );
}
