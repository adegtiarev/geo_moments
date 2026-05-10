// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedMomentsTable extends CachedMoments
    with TableInfo<$CachedMomentsTable, CachedMoment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMomentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emotionMeta = const VerificationMeta(
    'emotion',
  );
  @override
  late final GeneratedColumn<String> emotion = GeneratedColumn<String>(
    'emotion',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaUrlMeta = const VerificationMeta(
    'mediaUrl',
  );
  @override
  late final GeneratedColumn<String> mediaUrl = GeneratedColumn<String>(
    'media_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorDisplayNameMeta = const VerificationMeta(
    'authorDisplayName',
  );
  @override
  late final GeneratedColumn<String> authorDisplayName =
      GeneratedColumn<String>(
        'author_display_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _authorAvatarUrlMeta = const VerificationMeta(
    'authorAvatarUrl',
  );
  @override
  late final GeneratedColumn<String> authorAvatarUrl = GeneratedColumn<String>(
    'author_avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _likeCountMeta = const VerificationMeta(
    'likeCount',
  );
  @override
  late final GeneratedColumn<int> likeCount = GeneratedColumn<int>(
    'like_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _commentCountMeta = const VerificationMeta(
    'commentCount',
  );
  @override
  late final GeneratedColumn<int> commentCount = GeneratedColumn<int>(
    'comment_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    authorId,
    latitude,
    longitude,
    body,
    emotion,
    mediaUrl,
    mediaType,
    authorDisplayName,
    authorAvatarUrl,
    likeCount,
    commentCount,
    createdAt,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_moments';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedMoment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('emotion')) {
      context.handle(
        _emotionMeta,
        emotion.isAcceptableOrUnknown(data['emotion']!, _emotionMeta),
      );
    }
    if (data.containsKey('media_url')) {
      context.handle(
        _mediaUrlMeta,
        mediaUrl.isAcceptableOrUnknown(data['media_url']!, _mediaUrlMeta),
      );
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('author_display_name')) {
      context.handle(
        _authorDisplayNameMeta,
        authorDisplayName.isAcceptableOrUnknown(
          data['author_display_name']!,
          _authorDisplayNameMeta,
        ),
      );
    }
    if (data.containsKey('author_avatar_url')) {
      context.handle(
        _authorAvatarUrlMeta,
        authorAvatarUrl.isAcceptableOrUnknown(
          data['author_avatar_url']!,
          _authorAvatarUrlMeta,
        ),
      );
    }
    if (data.containsKey('like_count')) {
      context.handle(
        _likeCountMeta,
        likeCount.isAcceptableOrUnknown(data['like_count']!, _likeCountMeta),
      );
    }
    if (data.containsKey('comment_count')) {
      context.handle(
        _commentCountMeta,
        commentCount.isAcceptableOrUnknown(
          data['comment_count']!,
          _commentCountMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedMoment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMoment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      emotion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emotion'],
      ),
      mediaUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_url'],
      ),
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      authorDisplayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_display_name'],
      ),
      authorAvatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_avatar_url'],
      ),
      likeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}like_count'],
      )!,
      commentCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}comment_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedMomentsTable createAlias(String alias) {
    return $CachedMomentsTable(attachedDatabase, alias);
  }
}

class CachedMoment extends DataClass implements Insertable<CachedMoment> {
  final String id;
  final String authorId;
  final double latitude;
  final double longitude;
  final String body;
  final String? emotion;
  final String? mediaUrl;
  final String mediaType;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime cachedAt;
  const CachedMoment({
    required this.id,
    required this.authorId,
    required this.latitude,
    required this.longitude,
    required this.body,
    this.emotion,
    this.mediaUrl,
    required this.mediaType,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['author_id'] = Variable<String>(authorId);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['text'] = Variable<String>(body);
    if (!nullToAbsent || emotion != null) {
      map['emotion'] = Variable<String>(emotion);
    }
    if (!nullToAbsent || mediaUrl != null) {
      map['media_url'] = Variable<String>(mediaUrl);
    }
    map['media_type'] = Variable<String>(mediaType);
    if (!nullToAbsent || authorDisplayName != null) {
      map['author_display_name'] = Variable<String>(authorDisplayName);
    }
    if (!nullToAbsent || authorAvatarUrl != null) {
      map['author_avatar_url'] = Variable<String>(authorAvatarUrl);
    }
    map['like_count'] = Variable<int>(likeCount);
    map['comment_count'] = Variable<int>(commentCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedMomentsCompanion toCompanion(bool nullToAbsent) {
    return CachedMomentsCompanion(
      id: Value(id),
      authorId: Value(authorId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      body: Value(body),
      emotion: emotion == null && nullToAbsent
          ? const Value.absent()
          : Value(emotion),
      mediaUrl: mediaUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaUrl),
      mediaType: Value(mediaType),
      authorDisplayName: authorDisplayName == null && nullToAbsent
          ? const Value.absent()
          : Value(authorDisplayName),
      authorAvatarUrl: authorAvatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(authorAvatarUrl),
      likeCount: Value(likeCount),
      commentCount: Value(commentCount),
      createdAt: Value(createdAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedMoment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMoment(
      id: serializer.fromJson<String>(json['id']),
      authorId: serializer.fromJson<String>(json['authorId']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      body: serializer.fromJson<String>(json['body']),
      emotion: serializer.fromJson<String?>(json['emotion']),
      mediaUrl: serializer.fromJson<String?>(json['mediaUrl']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      authorDisplayName: serializer.fromJson<String?>(
        json['authorDisplayName'],
      ),
      authorAvatarUrl: serializer.fromJson<String?>(json['authorAvatarUrl']),
      likeCount: serializer.fromJson<int>(json['likeCount']),
      commentCount: serializer.fromJson<int>(json['commentCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'authorId': serializer.toJson<String>(authorId),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'body': serializer.toJson<String>(body),
      'emotion': serializer.toJson<String?>(emotion),
      'mediaUrl': serializer.toJson<String?>(mediaUrl),
      'mediaType': serializer.toJson<String>(mediaType),
      'authorDisplayName': serializer.toJson<String?>(authorDisplayName),
      'authorAvatarUrl': serializer.toJson<String?>(authorAvatarUrl),
      'likeCount': serializer.toJson<int>(likeCount),
      'commentCount': serializer.toJson<int>(commentCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedMoment copyWith({
    String? id,
    String? authorId,
    double? latitude,
    double? longitude,
    String? body,
    Value<String?> emotion = const Value.absent(),
    Value<String?> mediaUrl = const Value.absent(),
    String? mediaType,
    Value<String?> authorDisplayName = const Value.absent(),
    Value<String?> authorAvatarUrl = const Value.absent(),
    int? likeCount,
    int? commentCount,
    DateTime? createdAt,
    DateTime? cachedAt,
  }) => CachedMoment(
    id: id ?? this.id,
    authorId: authorId ?? this.authorId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    body: body ?? this.body,
    emotion: emotion.present ? emotion.value : this.emotion,
    mediaUrl: mediaUrl.present ? mediaUrl.value : this.mediaUrl,
    mediaType: mediaType ?? this.mediaType,
    authorDisplayName: authorDisplayName.present
        ? authorDisplayName.value
        : this.authorDisplayName,
    authorAvatarUrl: authorAvatarUrl.present
        ? authorAvatarUrl.value
        : this.authorAvatarUrl,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    createdAt: createdAt ?? this.createdAt,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedMoment copyWithCompanion(CachedMomentsCompanion data) {
    return CachedMoment(
      id: data.id.present ? data.id.value : this.id,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      body: data.body.present ? data.body.value : this.body,
      emotion: data.emotion.present ? data.emotion.value : this.emotion,
      mediaUrl: data.mediaUrl.present ? data.mediaUrl.value : this.mediaUrl,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      authorDisplayName: data.authorDisplayName.present
          ? data.authorDisplayName.value
          : this.authorDisplayName,
      authorAvatarUrl: data.authorAvatarUrl.present
          ? data.authorAvatarUrl.value
          : this.authorAvatarUrl,
      likeCount: data.likeCount.present ? data.likeCount.value : this.likeCount,
      commentCount: data.commentCount.present
          ? data.commentCount.value
          : this.commentCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMoment(')
          ..write('id: $id, ')
          ..write('authorId: $authorId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('body: $body, ')
          ..write('emotion: $emotion, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaType: $mediaType, ')
          ..write('authorDisplayName: $authorDisplayName, ')
          ..write('authorAvatarUrl: $authorAvatarUrl, ')
          ..write('likeCount: $likeCount, ')
          ..write('commentCount: $commentCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    authorId,
    latitude,
    longitude,
    body,
    emotion,
    mediaUrl,
    mediaType,
    authorDisplayName,
    authorAvatarUrl,
    likeCount,
    commentCount,
    createdAt,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMoment &&
          other.id == this.id &&
          other.authorId == this.authorId &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.body == this.body &&
          other.emotion == this.emotion &&
          other.mediaUrl == this.mediaUrl &&
          other.mediaType == this.mediaType &&
          other.authorDisplayName == this.authorDisplayName &&
          other.authorAvatarUrl == this.authorAvatarUrl &&
          other.likeCount == this.likeCount &&
          other.commentCount == this.commentCount &&
          other.createdAt == this.createdAt &&
          other.cachedAt == this.cachedAt);
}

class CachedMomentsCompanion extends UpdateCompanion<CachedMoment> {
  final Value<String> id;
  final Value<String> authorId;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String> body;
  final Value<String?> emotion;
  final Value<String?> mediaUrl;
  final Value<String> mediaType;
  final Value<String?> authorDisplayName;
  final Value<String?> authorAvatarUrl;
  final Value<int> likeCount;
  final Value<int> commentCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedMomentsCompanion({
    this.id = const Value.absent(),
    this.authorId = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.body = const Value.absent(),
    this.emotion = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.authorDisplayName = const Value.absent(),
    this.authorAvatarUrl = const Value.absent(),
    this.likeCount = const Value.absent(),
    this.commentCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMomentsCompanion.insert({
    required String id,
    required String authorId,
    required double latitude,
    required double longitude,
    required String body,
    this.emotion = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    required String mediaType,
    this.authorDisplayName = const Value.absent(),
    this.authorAvatarUrl = const Value.absent(),
    this.likeCount = const Value.absent(),
    this.commentCount = const Value.absent(),
    required DateTime createdAt,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       authorId = Value(authorId),
       latitude = Value(latitude),
       longitude = Value(longitude),
       body = Value(body),
       mediaType = Value(mediaType),
       createdAt = Value(createdAt),
       cachedAt = Value(cachedAt);
  static Insertable<CachedMoment> custom({
    Expression<String>? id,
    Expression<String>? authorId,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? body,
    Expression<String>? emotion,
    Expression<String>? mediaUrl,
    Expression<String>? mediaType,
    Expression<String>? authorDisplayName,
    Expression<String>? authorAvatarUrl,
    Expression<int>? likeCount,
    Expression<int>? commentCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (authorId != null) 'author_id': authorId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (body != null) 'text': body,
      if (emotion != null) 'emotion': emotion,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaType != null) 'media_type': mediaType,
      if (authorDisplayName != null) 'author_display_name': authorDisplayName,
      if (authorAvatarUrl != null) 'author_avatar_url': authorAvatarUrl,
      if (likeCount != null) 'like_count': likeCount,
      if (commentCount != null) 'comment_count': commentCount,
      if (createdAt != null) 'created_at': createdAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMomentsCompanion copyWith({
    Value<String>? id,
    Value<String>? authorId,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<String>? body,
    Value<String?>? emotion,
    Value<String?>? mediaUrl,
    Value<String>? mediaType,
    Value<String?>? authorDisplayName,
    Value<String?>? authorAvatarUrl,
    Value<int>? likeCount,
    Value<int>? commentCount,
    Value<DateTime>? createdAt,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedMomentsCompanion(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      body: body ?? this.body,
      emotion: emotion ?? this.emotion,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (emotion.present) {
      map['emotion'] = Variable<String>(emotion.value);
    }
    if (mediaUrl.present) {
      map['media_url'] = Variable<String>(mediaUrl.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (authorDisplayName.present) {
      map['author_display_name'] = Variable<String>(authorDisplayName.value);
    }
    if (authorAvatarUrl.present) {
      map['author_avatar_url'] = Variable<String>(authorAvatarUrl.value);
    }
    if (likeCount.present) {
      map['like_count'] = Variable<int>(likeCount.value);
    }
    if (commentCount.present) {
      map['comment_count'] = Variable<int>(commentCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMomentsCompanion(')
          ..write('id: $id, ')
          ..write('authorId: $authorId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('body: $body, ')
          ..write('emotion: $emotion, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaType: $mediaType, ')
          ..write('authorDisplayName: $authorDisplayName, ')
          ..write('authorAvatarUrl: $authorAvatarUrl, ')
          ..write('likeCount: $likeCount, ')
          ..write('commentCount: $commentCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedMomentsTable cachedMoments = $CachedMomentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedMoments];
}

typedef $$CachedMomentsTableCreateCompanionBuilder =
    CachedMomentsCompanion Function({
      required String id,
      required String authorId,
      required double latitude,
      required double longitude,
      required String body,
      Value<String?> emotion,
      Value<String?> mediaUrl,
      required String mediaType,
      Value<String?> authorDisplayName,
      Value<String?> authorAvatarUrl,
      Value<int> likeCount,
      Value<int> commentCount,
      required DateTime createdAt,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedMomentsTableUpdateCompanionBuilder =
    CachedMomentsCompanion Function({
      Value<String> id,
      Value<String> authorId,
      Value<double> latitude,
      Value<double> longitude,
      Value<String> body,
      Value<String?> emotion,
      Value<String?> mediaUrl,
      Value<String> mediaType,
      Value<String?> authorDisplayName,
      Value<String?> authorAvatarUrl,
      Value<int> likeCount,
      Value<int> commentCount,
      Value<DateTime> createdAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedMomentsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMomentsTable> {
  $$CachedMomentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emotion => $composableBuilder(
    column: $table.emotion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorDisplayName => $composableBuilder(
    column: $table.authorDisplayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorAvatarUrl => $composableBuilder(
    column: $table.authorAvatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likeCount => $composableBuilder(
    column: $table.likeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get commentCount => $composableBuilder(
    column: $table.commentCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedMomentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMomentsTable> {
  $$CachedMomentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emotion => $composableBuilder(
    column: $table.emotion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorDisplayName => $composableBuilder(
    column: $table.authorDisplayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorAvatarUrl => $composableBuilder(
    column: $table.authorAvatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likeCount => $composableBuilder(
    column: $table.likeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get commentCount => $composableBuilder(
    column: $table.commentCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedMomentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMomentsTable> {
  $$CachedMomentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get emotion =>
      $composableBuilder(column: $table.emotion, builder: (column) => column);

  GeneratedColumn<String> get mediaUrl =>
      $composableBuilder(column: $table.mediaUrl, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get authorDisplayName => $composableBuilder(
    column: $table.authorDisplayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorAvatarUrl => $composableBuilder(
    column: $table.authorAvatarUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get likeCount =>
      $composableBuilder(column: $table.likeCount, builder: (column) => column);

  GeneratedColumn<int> get commentCount => $composableBuilder(
    column: $table.commentCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedMomentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedMomentsTable,
          CachedMoment,
          $$CachedMomentsTableFilterComposer,
          $$CachedMomentsTableOrderingComposer,
          $$CachedMomentsTableAnnotationComposer,
          $$CachedMomentsTableCreateCompanionBuilder,
          $$CachedMomentsTableUpdateCompanionBuilder,
          (
            CachedMoment,
            BaseReferences<_$AppDatabase, $CachedMomentsTable, CachedMoment>,
          ),
          CachedMoment,
          PrefetchHooks Function()
        > {
  $$CachedMomentsTableTableManager(_$AppDatabase db, $CachedMomentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMomentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedMomentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedMomentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> authorId = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> emotion = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String?> authorDisplayName = const Value.absent(),
                Value<String?> authorAvatarUrl = const Value.absent(),
                Value<int> likeCount = const Value.absent(),
                Value<int> commentCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedMomentsCompanion(
                id: id,
                authorId: authorId,
                latitude: latitude,
                longitude: longitude,
                body: body,
                emotion: emotion,
                mediaUrl: mediaUrl,
                mediaType: mediaType,
                authorDisplayName: authorDisplayName,
                authorAvatarUrl: authorAvatarUrl,
                likeCount: likeCount,
                commentCount: commentCount,
                createdAt: createdAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String authorId,
                required double latitude,
                required double longitude,
                required String body,
                Value<String?> emotion = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                required String mediaType,
                Value<String?> authorDisplayName = const Value.absent(),
                Value<String?> authorAvatarUrl = const Value.absent(),
                Value<int> likeCount = const Value.absent(),
                Value<int> commentCount = const Value.absent(),
                required DateTime createdAt,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedMomentsCompanion.insert(
                id: id,
                authorId: authorId,
                latitude: latitude,
                longitude: longitude,
                body: body,
                emotion: emotion,
                mediaUrl: mediaUrl,
                mediaType: mediaType,
                authorDisplayName: authorDisplayName,
                authorAvatarUrl: authorAvatarUrl,
                likeCount: likeCount,
                commentCount: commentCount,
                createdAt: createdAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedMomentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedMomentsTable,
      CachedMoment,
      $$CachedMomentsTableFilterComposer,
      $$CachedMomentsTableOrderingComposer,
      $$CachedMomentsTableAnnotationComposer,
      $$CachedMomentsTableCreateCompanionBuilder,
      $$CachedMomentsTableUpdateCompanionBuilder,
      (
        CachedMoment,
        BaseReferences<_$AppDatabase, $CachedMomentsTable, CachedMoment>,
      ),
      CachedMoment,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedMomentsTableTableManager get cachedMoments =>
      $$CachedMomentsTableTableManager(_db, _db.cachedMoments);
}
