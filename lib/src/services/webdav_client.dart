import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';

class WebDavClient {
  WebDavClient({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<void> uploadBackup(WebDavConfig config, String payload) async {
    final endpoint = _endpoint(config);
    await _ensureCollections(config, endpoint.collectionUris);
    final request = await _open(config, 'PUT', endpoint.fileUri);
    final bytes = utf8.encode(payload);
    request.headers.contentType = ContentType.json;
    request.headers.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close();
    await _ensureOk(
      response,
      allowed: {200, 201, 204},
      notFoundMessage:
          '云端备份路径不存在，请检查坚果云地址或远端备份文件名；建议使用 shift-ledger/shift-ledger-backup.json 这类应用专属目录路径',
    );
  }

  Future<String> downloadBackup(WebDavConfig config) async {
    final request = await _open(config, 'GET', _endpoint(config).fileUri);
    final response = await request.close();
    await _ensureOk(
      response,
      allowed: {200},
      notFoundMessage: '云端还没有这个备份文件，请先备份一次，或检查远端备份文件名',
    );
    return utf8.decode(
      await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
    );
  }

  Future<void> _ensureCollections(
    WebDavConfig config,
    List<Uri> collectionUris,
  ) async {
    for (final uri in collectionUris) {
      final request = await _open(config, 'MKCOL', uri);
      final response = await request.close();
      await _ensureOk(
        response,
        allowed: {200, 201, 204, 301, 405},
        notFoundMessage: '云端备份目录不存在，请检查坚果云地址',
      );
    }
  }

  Future<HttpClientRequest> _open(
    WebDavConfig config,
    String method,
    Uri uri,
  ) async {
    if (config.url.isEmpty ||
        config.username.isEmpty ||
        config.appPassword.isEmpty) {
      throw const WebDavException('请先填写坚果云地址、账号和应用授权密码');
    }
    final request = await _client
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 12));
    final auth = base64Encode(
      utf8.encode('${config.username}:${config.appPassword}'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Basic $auth');
    return request;
  }

  Future<void> _ensureOk(
    HttpClientResponse response, {
    required Set<int> allowed,
    String? notFoundMessage,
  }) async {
    if (allowed.contains(response.statusCode)) return;
    final body = utf8.decode(
      await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
    );
    if (response.statusCode == 404 && notFoundMessage != null) {
      throw WebDavException('$notFoundMessage（HTTP 404）');
    }
    final detail = _compactBody(body);
    throw WebDavException(
      detail.isEmpty
          ? 'WebDAV 请求失败：HTTP ${response.statusCode}'
          : 'WebDAV 请求失败：HTTP ${response.statusCode} $detail',
    );
  }

  _WebDavEndpoint _endpoint(WebDavConfig config) {
    final remotePath = _normalizedRemotePath(config.remotePath);
    final baseUri = _normalizedBaseUri(config.url);
    final fileUri = baseUri.resolve(remotePath);
    final segments = remotePath.split('/');
    final collectionUris = <Uri>[];
    if (segments.length > 1) {
      var partial = '';
      for (final segment in segments.take(segments.length - 1)) {
        partial = '$partial$segment/';
        collectionUris.add(baseUri.resolve(partial));
      }
    }
    return _WebDavEndpoint(fileUri: fileUri, collectionUris: collectionUris);
  }

  Uri _normalizedBaseUri(String url) {
    final uri = Uri.parse(url.trim());
    final path = uri.path.isEmpty
        ? '/'
        : uri.path.endsWith('/')
        ? uri.path
        : '${uri.path}/';
    return uri.replace(path: path);
  }

  String _normalizedRemotePath(String remotePath) {
    final trimmed = remotePath.trim();
    final normalized = trimmed.replaceAll(RegExp(r'^/+|/+$'), '');
    return normalized.isEmpty ? defaultWebDavRemotePath : normalized;
  }

  String _compactBody(String body) {
    final cleaned = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.length <= 160 ? cleaned : '${cleaned.substring(0, 160)}…';
  }
}

class WebDavException implements Exception {
  const WebDavException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _WebDavEndpoint {
  const _WebDavEndpoint({required this.fileUri, required this.collectionUris});

  final Uri fileUri;
  final List<Uri> collectionUris;
}
