import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/src/domain/models.dart';
import 'package:shift_ledger/src/services/webdav_client.dart';

void main() {
  group('WebDavClient', () {
    late HttpServer server;
    late List<_CapturedRequest> requests;

    setUp(() async {
      requests = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(
        server.forEach((request) async {
          final body = utf8.decode(
            await request.fold<List<int>>(
              [],
              (all, chunk) => all..addAll(chunk),
            ),
          );
          requests.add(
            _CapturedRequest(
              method: request.method,
              path: request.uri.path,
              authorization: request.headers.value(
                HttpHeaders.authorizationHeader,
              ),
              body: body,
            ),
          );

          switch (request.method) {
            case 'MKCOL':
              request.response.statusCode = request.uri.path == '/dav/nested/'
                  ? 201
                  : 405;
              break;
            case 'PUT':
              request.response.statusCode = 201;
              break;
            case 'GET':
              request.response.statusCode = 200;
              request.response.write('{"ok":true}');
              break;
            default:
              request.response.statusCode = 405;
          }
          await request.response.close();
        }),
      );
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('upload creates missing parent collections before PUT', () async {
      final client = WebDavClient();
      final config = WebDavConfig(
        url: 'http://127.0.0.1:${server.port}/dav',
        username: 'worker@example.com',
        appPassword: 'app-pass',
        remotePath: 'nested/shift-ledger-backup.json',
      );

      await client.uploadBackup(config, '{"entries":[]}');
      final downloaded = await client.downloadBackup(config);

      expect(downloaded, '{"ok":true}');
      expect(requests, hasLength(3));

      final auth =
          'Basic ${base64Encode(utf8.encode('worker@example.com:app-pass'))}';

      expect(requests[0].method, 'MKCOL');
      expect(requests[0].path, '/dav/nested/');
      expect(requests[0].authorization, auth);

      expect(requests[1].method, 'PUT');
      expect(requests[1].path, '/dav/nested/shift-ledger-backup.json');
      expect(requests[1].authorization, auth);
      expect(requests[1].body, '{"entries":[]}');

      expect(requests[2].method, 'GET');
      expect(requests[2].path, '/dav/nested/shift-ledger-backup.json');
      expect(requests[2].authorization, auth);
    });

    test('download 404 returns a friendly missing-backup message', () async {
      await server.close(force: true);
      requests = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(
        server.forEach((request) async {
          request.response.statusCode = 404;
          request.response.write(
            '<?xml version="1.0"?><d:error xmlns:d="DAV:"><s:message xmlns:s="http://ns.jianguoyun.com">ObjectNotFound</s:message></d:error>',
          );
          await request.response.close();
        }),
      );

      final client = WebDavClient();
      final config = WebDavConfig(
        url: 'http://127.0.0.1:${server.port}/dav/',
        username: 'worker@example.com',
        appPassword: 'app-pass',
        remotePath: 'shift-ledger-backup.json',
      );

      expect(
        () => client.downloadBackup(config),
        throwsA(
          isA<WebDavException>().having(
            (error) => error.message,
            'message',
            '云端还没有这个备份文件，请先备份一次，或检查远端备份文件名（HTTP 404）',
          ),
        ),
      );
    });
  });
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.authorization,
    required this.body,
  });

  final String method;
  final String path;
  final String? authorization;
  final String body;
}
