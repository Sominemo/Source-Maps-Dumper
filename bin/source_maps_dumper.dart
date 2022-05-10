import 'dart:convert';
import 'dart:io';

import 'dart:math';
import 'package:http/http.dart' as http;

void main(List<String> arguments) async {
  if (arguments.length < 2) {
    print(
      '''Usage: source_maps_dumper path/to/file.har output_dir [--save-all] [--ignore-errors]
\t--save-all\tExtract all files, even if they don't have source maps
\t--ignore-errors\tDownload source maps even if response code is not 200 OK''',
    );

    return;
  }

  final saveAllScripts = arguments.contains('--save-all');
  final ignoreErrors = arguments.contains('--ignore-errors');

  print("Parsing HAR...");
  Object? har;
  try {
    final harStream = File(arguments[0]).openRead();

    har = await harStream
        .transform<String>(utf8.decoder)
        .transform<Object?>(json.decoder)
        .first;
  } catch (e) {
    print("Could not open file: $e");
    return;
  }

  late List list;

  try {
    list = ((har as Map<String, dynamic>)['log']
        as Map<String, dynamic>)['entries'] as List;
  } catch (e) {
    print("Could not parse HAR: $e");
    return;
  }

  print("HAR parsed.");

  final total = list.length;
  int processed = 0;
  int found = 0;
  int saved = 0;

  for (final entry in list) {
    clearProgress();
    processed++;
    updateProgress(processed, total, found, saved);

    if (entry is! Map<String, dynamic>) {
      continue;
    }

    if (!entry.containsKey('request') || !entry.containsKey('response')) {
      continue;
    }

    final response = entry['response'] as Map<String, dynamic>;
    final request = entry['request'] as Map<String, dynamic>;
    if (!response.containsKey('content')) {
      continue;
    }

    final content = response['content'] as Map<String, dynamic>;

    if (!content.containsKey('text')) {
      continue;
    }

    final contentText = (content)['text'] as String;

    if (!contentText.contains(
        'sourceMappingURL=', max(contentText.length - 500, 0))) {
      continue;
    }

    final url = Uri.parse(request['url'] as String);

    if (saveAllScripts) await saveFileWithUrl(contentText, url, arguments[1]);

    final fullMatch = RegExp(r'sourceMappingURL=([^\s]+)$', multiLine: true)
        .allMatches(contentText);

    for (var match in fullMatch) {
      clearProgress();
      found++;
      updateProgress(processed, total, found, saved);

      try {
        final mapUrl = (match[1] as String).contains('://')
            ? Uri.parse(match[1] as String)
            : url.replace(
                pathSegments: url.pathSegments
                    .sublist(0, url.pathSegments.length - 1)
                    .followedBy((match[1] as String).split('/')));

        final headers = <String, String>{};

        for (var e in request['headers'] as List<dynamic>) {
          final name = e['name'] as String;

          if (name.startsWith(':')) continue;

          headers[name] = e['value'] as String;
        }

        headers.removeWhere((key, value) => key.startsWith(':'));

        final mapContentRequest =
            (await http.Client().get(mapUrl, headers: headers));

        if (mapContentRequest.statusCode != 200 && !ignoreErrors) {
          clearProgress();
          print(
              "Failed to fetch map file: $mapUrl. STATUS CODE: ${mapContentRequest.statusCode}");
          updateProgress(processed, total, found, saved);
          continue;
        }

        final mapContent = mapContentRequest.body;

        if (!saveAllScripts) {
          await saveFileWithUrl(contentText, url, arguments[1]);
        }
        await saveFileWithUrl(mapContent, mapUrl, arguments[1]);

        clearProgress();
        print('Found source map for $url');
        saved++;
        updateProgress(processed, total, found, saved);
      } catch (e) {
        clearProgress();
        print('Found source map for $url');
        print(e);
        updateProgress(processed, total, found, saved);
        continue;
      }
    }
  }

  clearProgress();
  updateProgress(processed, total, found, saved);
}

Future<void> saveFileWithUrl(String content, Uri path, String p) async {
  final file = File(p + '/' + path.host + '/' + path.path);
  await file.create(recursive: true);
  await file.writeAsString(content);
}

int lastMessageLength = 0;

void clearProgress() {
  if (lastMessageLength > 0) stdout.write('\b' * lastMessageLength);
}

void updateProgress(processed, total, found, saved) {
  processed--;
  final percent = (processed / total * 100).toStringAsFixed(2);
  final message =
      '$percent% done ($processed/$total, $found found, $saved saved)';
  lastMessageLength = message.length;
  stdout.write(message);
}
