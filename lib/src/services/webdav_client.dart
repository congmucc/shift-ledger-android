import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';

class WebDavClient {
  WebDavClient({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<void> uploadBackup(WebDavConfig config, String payload) async {
    final request = await _open(config, 'PUT');
    final bytes = utf8.encode(payload);
    request.headers.contentType = ContentType.json;
    request.headers.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close();
    await _ensureOk(response, allowed: {200, 201, 204});
  }

  Future<String> downloadBackup(WebDavConfig config) async {
    final request = await _open(config, 'GET');
    final response = await request.close();
    await _ensureOk(response, allowed: {200});
    return utf8.decode(
      await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
    );
  }

  Future<HttpClientRequest> _open(WebDavConfig config, String method) async {
    if (config.url.isEmpty ||
        config.username.isEmpty ||
        config.appPassword.isEmpty) {
      throw const WebDavException('请先填写坚果云地址、账号和应用授权密码');
    }
    final base = config.url.endsWith('/') ? config.url : '${config.url}/';
    final uri = Uri.parse(base + config.remotePath);
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
  }) async {
    if (allowed.contains(response.statusCode)) return;
    final body = utf8.decode(
      await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
    );
    throw WebDavException('WebDAV 请求失败：HTTP ${response.statusCode} $body');
  }
}

class WebDavException implements Exception {
  const WebDavException(this.message);
  final String message;
  @override
  String toString() => message;
}
