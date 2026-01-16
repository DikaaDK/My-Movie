import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const _shortCatalogHost = 'dramabos.asia';

enum ShortCatalogNetwork {
  radReel,
  flickReels,
  dotDrama,
  netShort,
  shortMax,
  starShort,
  stardustTv,
  dramaDash,
  dramaWave,
  dramabox,
  viglo,
  micro,
  melolo,
  meloShort,
  reelife,
  hiShort,
}

extension ShortCatalogNetworkInfo on ShortCatalogNetwork {
  String get key {
    switch (this) {
      case ShortCatalogNetwork.radReel:
        return 'radreel';
      case ShortCatalogNetwork.flickReels:
        return 'flick';
      case ShortCatalogNetwork.dotDrama:
        return 'dotdrama';
      case ShortCatalogNetwork.netShort:
        return 'netshort';
      case ShortCatalogNetwork.shortMax:
        return 'shortmax';
      case ShortCatalogNetwork.starShort:
        return 'starshort';
      case ShortCatalogNetwork.stardustTv:
        return 'stardusttv';
      case ShortCatalogNetwork.dramaDash:
        return 'dramadash';
      case ShortCatalogNetwork.dramaWave:
        return 'dramawave';
      case ShortCatalogNetwork.dramabox:
        return 'dramabox';
      case ShortCatalogNetwork.viglo:
        return 'viglo';
      case ShortCatalogNetwork.micro:
        return 'micro';
      case ShortCatalogNetwork.melolo:
        return 'melolo';
      case ShortCatalogNetwork.meloShort:
        return 'meloshort';
      case ShortCatalogNetwork.reelife:
        return 'reelife';
      case ShortCatalogNetwork.hiShort:
        return 'hishort';
    }
  }

  String get displayName {
    switch (this) {
      case ShortCatalogNetwork.radReel:
        return 'RadReel';
      case ShortCatalogNetwork.flickReels:
        return 'FlickReels';
      case ShortCatalogNetwork.dotDrama:
        return 'DotDrama';
      case ShortCatalogNetwork.netShort:
        return 'NetShort';
      case ShortCatalogNetwork.shortMax:
        return 'ShortMax';
      case ShortCatalogNetwork.starShort:
        return 'StarShort';
      case ShortCatalogNetwork.stardustTv:
        return 'StardustTV';
      case ShortCatalogNetwork.dramaDash:
        return 'DramaDash';
      case ShortCatalogNetwork.dramaWave:
        return 'DramaWave';
      case ShortCatalogNetwork.dramabox:
        return 'Dramabox';
      case ShortCatalogNetwork.viglo:
        return 'Viglo';
      case ShortCatalogNetwork.micro:
        return 'Micro';
      case ShortCatalogNetwork.melolo:
        return 'Melolo';
      case ShortCatalogNetwork.meloShort:
        return 'MeloShort';
      case ShortCatalogNetwork.reelife:
        return 'Reelife';
      case ShortCatalogNetwork.hiShort:
        return 'HiShort';
    }
  }
}

class ShortCatalogFetchResult {
  const ShortCatalogFetchResult({
    required this.network,
    required this.uri,
    this.payload,
    this.error,
  });

  final ShortCatalogNetwork network;
  final Uri uri;
  final Object? payload;
  final String? error;

  bool get isSuccess => error == null && payload != null;
}

class ShortCatalogApi {
  const ShortCatalogApi();

  static const _requestTimeout = Duration(seconds: 12);

  static final Map<ShortCatalogNetwork, _ShortCatalogEndpoint> _endpoints = {
    ShortCatalogNetwork.radReel: _ShortCatalogEndpoint(
      path: '/api/v1/home',
      query: {'lang': 'id', 'tab': '17', 'page': '1'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.flickReels: _ShortCatalogEndpoint(
      path: '/home',
      query: {'page': '1', 'page_size': '30', 'lang': '6'},
      limitParam: 'page_size',
    ),
    ShortCatalogNetwork.dotDrama: _ShortCatalogEndpoint(
      path: '/api/drama/list',
      query: {'page': '1', 'limit': '30', 'lang': 'id'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.netShort: _ShortCatalogEndpoint(
      path: '/api/drama/explore',
      query: {'offset': '0', 'limit': '30'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.shortMax: _ShortCatalogEndpoint(
      path: '/api/v1/home',
      query: {'lang': 'id', 'tab': '1', 'page': '1'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.starShort: _ShortCatalogEndpoint(
      path: '/api/v1/home',
      query: {'lang': '4', 'page': '1'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.stardustTv: _ShortCatalogEndpoint(
      path: '/home',
      query: {'page': '1', 'limit': '30'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.dramaDash: _ShortCatalogEndpoint(
      path: '/api/home',
      query: {'page': '1', 'limit': '30'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.dramaWave: _ShortCatalogEndpoint(
      path: '/api/v1/feed/new',
      query: {'lang': 'id', 'page': '1'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.dramabox: _ShortCatalogEndpoint(
      path: '/api/new/1',
      query: {'lang': 'in', 'limit': '30'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.viglo: _ShortCatalogEndpoint(
      path: '/api/v1/home',
      query: {'lang': 'id', 'limit': '30'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.micro: _ShortCatalogEndpoint(
      path: '/api/v1/list',
      query: {'lang': 'id', 'page': '1'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.melolo: _ShortCatalogEndpoint(
      path: '/api/v1/home',
      query: {'offset': '0', 'count': '30', 'lang': 'id'},
      limitParam: 'count',
    ),
    ShortCatalogNetwork.meloShort: _ShortCatalogEndpoint(
      path: '/api/home',
      query: {'page': '1'},
      limitParam: 'page_size',
    ),
    ShortCatalogNetwork.reelife: _ShortCatalogEndpoint(
      path: '/v1/home',
      query: {'page': '1'},
      limitParam: 'limit',
    ),
    ShortCatalogNetwork.hiShort: _ShortCatalogEndpoint(
      path: '/api/v1/home',
      query: {'module': '12', 'page': '1'},
      limitParam: 'limit',
    ),
  };

  Future<List<ShortCatalogFetchResult>> fetchAll({
    int limitPerNetwork = 40,
  }) async {
    final normalizedLimit = _normalizeLimit(limitPerNetwork);
    final tasks = _endpoints.keys.map(
      (network) => fetchNetwork(network, limit: normalizedLimit),
    );
    return Future.wait(tasks);
  }

  Future<ShortCatalogFetchResult> fetchNetwork(
    ShortCatalogNetwork network, {
    int limit = 40,
  }) async {
    final endpoint = _endpoints[network];
    final normalizedLimit = _normalizeLimit(limit);
    if (endpoint == null) {
      return ShortCatalogFetchResult(
        network: network,
        uri: _catalogBaseUri(network),
        error: 'Endpoint for ${network.displayName} is not defined.',
      );
    }
    final query = endpoint.queryWithLimit(normalizedLimit);
    final uri = _buildCatalogUri(network, endpoint.pathSegments, query);
    try {
      final response = await http.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        return ShortCatalogFetchResult(
          network: network,
          uri: uri,
          error: 'Server returned ${response.statusCode}',
        );
      }
      final decoded = jsonDecode(response.body);
      final payload = _unwrapPayload(decoded);
      return ShortCatalogFetchResult(
        network: network,
        uri: uri,
        payload: payload,
      );
    } catch (error) {
      return ShortCatalogFetchResult(
        network: network,
        uri: uri,
        error: error.toString(),
      );
    }
  }
}

class _ShortCatalogEndpoint {
  const _ShortCatalogEndpoint({
    required this.path,
    required this.query,
    this.limitParam,
  });

  final String path;
  final Map<String, String> query;
  final String? limitParam;

  List<String> get pathSegments =>
      path.split('/').where((segment) => segment.trim().isNotEmpty).toList();

  Map<String, String> queryWithLimit(int limit) {
    final result = Map<String, String>.from(query);
    if (limitParam != null) {
      result[limitParam!] = limit.toString();
    }
    return result;
  }
}

int _normalizeLimit(int limit) {
  const minLimit = 5;
  const maxLimit = 80;
  if (limit < minLimit) {
    return minLimit;
  }
  if (limit > maxLimit) {
    return maxLimit;
  }
  return limit;
}

Uri _buildCatalogUri(
  ShortCatalogNetwork network,
  List<String> pathSegments,
  Map<String, String> query,
) {
  final segments = ['api', network.key, ...pathSegments];
  return Uri(
    scheme: 'https',
    host: _shortCatalogHost,
    pathSegments: segments,
    queryParameters: query.isEmpty ? null : query,
  );
}

Uri _catalogBaseUri(ShortCatalogNetwork network) => Uri(
  scheme: 'https',
  host: _shortCatalogHost,
  pathSegments: ['api', network.key],
);

Object _unwrapPayload(dynamic decoded) {
  if (decoded is Map<String, dynamic>) {
    if (decoded.containsKey('data')) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        if (data.containsKey('list')) {
          return data['list'];
        }
        if (data.containsKey('items')) {
          return data['items'];
        }
      }
      return data;
    }
    if (decoded.containsKey('list')) {
      return decoded['list'];
    }
    if (decoded.containsKey('items')) {
      return decoded['items'];
    }
    if (decoded.containsKey('dramas')) {
      return decoded['dramas'];
    }
  }
  return decoded;
}
