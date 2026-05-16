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
            await request.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
          );
          requests.add(
            _CapturedRequest(
              method: request.method,
              path: request.uri.path,
              authorization: request.headers.value(HttpHeaders.authorizationHeader),
              depth: request.headers.value('Depth'),
              body: body,
            ),
          );

          switch (request.method) {
            case 'PUT':
              request.response.statusCode = 201;
              break;
            case 'GET':
              request.response.statusCode = 200;
              request.response.write('{"ok":true}');
              break;
            case 'PROPFIND':
              request.response.statusCode = 207;
              request.response.write('<multistatus />');
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

    test('upload download and listing use expected endpoints and auth', () async {
      final client = WebDavClient();
      final config = WebDavConfig(
        url: 'http://127.0.0.1:${server.port}/dav',
        username: 'worker@example.com',
        appPassword: 'app-pass',
        remotePath: 'nested/shift-ledger-backup.json',
      );

      await client.uploadBackup(config, '{"entries":[]}');
      final downloaded = await client.downloadBackup(config);
      final listing = await client.listBackups(config);

      expect(downloaded, '{"ok":true}');
      expect(listing, '<multistatus />');
      expect(requests, hasLength(3));

      final auth = 'Basic ${base64Encode(utf8.encode('worker@example.com:app-pass'))}';

      expect(requests[0].method, 'PUT');
      expect(requests[0].path, '/dav/nested/shift-ledger-backup.json');
      expect(requests[0].authorization, auth);
      expect(requests[0].body, '{"entries":[]}');

      expect(requests[1].method, 'GET');
      expect(requests[1].path, '/dav/nested/shift-ledger-backup.json');
      expect(requests[1].authorization, auth);

      expect(requests[2].method, 'PROPFIND');
      expect(requests[2].path, '/dav/');
      expect(requests[2].authorization, auth);
      expect(requests[2].depth, '1');
    });
  });
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.authorization,
    required this.depth,
    required this.body,
  });

  final String method;
  final String path;
  final String? authorization;
  final String? depth;
  final String body;
}
