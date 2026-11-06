import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const noInternetMessage =
    'Sin conexión a Internet. Verifique su conexión y vuelva a intentarlo.';
const serverUnavailableMessage =
    'El servicio se encuentra temporalmente no disponible. '
    'Vuelva a intentarlo más tarde.';
const connectionFailedMessage =
    'No se pudo conectar con el servicio. '
    'Verifique su conexión y vuelva a intentarlo.';
const connectionCheckFailedMessage =
    'No se pudo verificar la conexión. Vuelva a intentarlo.';

class RequestFailure implements Exception {
  final String message;
  final int? statusCode;

  const RequestFailure(this.message, {this.statusCode});

  @override
  String toString() => message;
}

void logRequestFailure(String operation, Object error, StackTrace stackTrace) {
  final status = error is RequestFailure ? error.statusCode : null;
  debugPrint(
    '[$operation] ${error.runtimeType}'
    '${status == null ? '' : ' (HTTP $status)'}',
  );
  debugPrintStack(stackTrace: stackTrace, maxFrames: 5);
}

String requestErrorMessage(Object error, {required String fallbackMessage}) {
  return error is RequestFailure ? error.message : fallbackMessage;
}

RequestFailure httpRequestFailure(
  int statusCode, {
  required String fallbackMessage,
}) {
  final String message;
  if (statusCode == 401) {
    message =
        'Sesión vencida o no autorizada. '
        'Cierra sesión e ingresa nuevamente.';
  } else if (statusCode == 403) {
    message = 'No tiene permiso para consultar esta información.';
  } else if (statusCode == 404) {
    message = 'No se encontró la información solicitada.';
  } else if (statusCode == 400 || statusCode == 422) {
    message =
        'No se pudo completar la solicitud. Verifique los datos enviados.';
  } else if (statusCode >= 500 || statusCode == 408) {
    message = serverUnavailableMessage;
  } else {
    message = fallbackMessage;
  }
  return RequestFailure(message, statusCode: statusCode);
}

Future<bool> _hasNetworkConnection() async {
  try {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  } on PlatformException catch (error, stackTrace) {
    logRequestFailure('Comprobar conexión', error, stackTrace);
    throw const RequestFailure(connectionCheckFailedMessage);
  } on MissingPluginException catch (error, stackTrace) {
    logRequestFailure('Comprobar conexión', error, stackTrace);
    throw const RequestFailure(connectionCheckFailedMessage);
  }
}

Future<RequestFailure> _transportFailure(
  Object error,
  StackTrace stackTrace,
  String message,
) async {
  logRequestFailure('Comunicación con el servicio', error, stackTrace);
  final hasConnection = await _hasNetworkConnection();
  return RequestFailure(hasConnection ? message : noInternetMessage);
}

Future<T> runNetworkRequest<T>(Future<T> Function() request) async {
  if (!await _hasNetworkConnection()) {
    throw const RequestFailure(noInternetMessage);
  }

  try {
    return await request();
  } on TimeoutException catch (error, stackTrace) {
    throw await _transportFailure(error, stackTrace, serverUnavailableMessage);
  } on http.ClientException catch (error, stackTrace) {
    throw await _transportFailure(error, stackTrace, connectionFailedMessage);
  } on SocketException catch (error, stackTrace) {
    throw await _transportFailure(error, stackTrace, connectionFailedMessage);
  }
}
