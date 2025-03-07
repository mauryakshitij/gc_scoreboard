import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../functions/auth_user_helper.dart';
import '../functions/snackbar.dart';
import '../globals/constants.dart';
import '../globals/enums.dart';
import '../models/manthan_models/manthan_event_model.dart';
import '../models/manthan_models/manthan_result_model.dart';
import '../models/sahyog_models/sahyog_event_model.dart';
import '../models/sahyog_models/sahyog_result_model.dart';
import '../models/spardha_models/spardha_event_model.dart';
import '../models/kriti_models/kriti_event_model.dart';
import '../models/kriti_models/kriti_result_model.dart';
import '../models/spardha_models/spardha_result_model.dart';
import '../models/standing_model.dart';
import '../stores/common_store.dart';

class APIService {
  final dio = Dio(BaseOptions(
      baseUrl: const String.fromEnvironment('SERVER-URL'),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Security-Key': const String.fromEnvironment('SECURITY-KEY')}));

  APIService(BuildContext buildContext) {
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      options.headers["Authorization"] =
          "Bearer ${await AuthUserHelpers.getAccessToken()}";
      handler.next(options);
    }, onError: (error, handler) async {
      var response = error.response;
      if (response != null && response.statusCode == 401) {
        bool couldRegenerate = await regenerateAccessToken();
        // ignore: use_build_context_synchronously
        var commStore = buildContext.read<CommonStore>();
        if (couldRegenerate) {
          // retry
          return handler.resolve(await retryRequest(response));
        } else if (!commStore.isAdmin) {
          // normal user
          await generateTokens(commStore);
          // retry
          return handler.resolve(await retryRequest(response));
        } else {
          // ignore: use_build_context_synchronously
          showSnackBar(buildContext,
              "Your session has expired!! Login again in OneStop.");
        }
      }
      // admin user with expired tokens
      return handler.next(error);
    }));
  }

  Future<Response<dynamic>> retryRequest(Response response) async {
    RequestOptions requestOptions = response.requestOptions;
    response.requestOptions.headers[DatabaseRecords.authorization] =
        "Bearer ${await AuthUserHelpers.getAccessToken()}";
    final options =
        Options(method: requestOptions.method, headers: requestOptions.headers);
    Dio retryDio = Dio(BaseOptions(
        baseUrl: const String.fromEnvironment('SERVER-URL'),
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          'Security-Key': const String.fromEnvironment('SECURITY-KEY')
        }));
    if (requestOptions.method == "GET") {
      return retryDio.request(requestOptions.path,
          queryParameters: requestOptions.queryParameters, options: options);
    } else {
      return retryDio.request(requestOptions.path,
          queryParameters: requestOptions.queryParameters,
          data: requestOptions.data,
          options: options);
    }
  }

  Future<dynamic> generateTokens(CommonStore commStore) async {
    Map<String, String> userData = await AuthUserHelpers.getUserData();
    Response<Map<String, dynamic>> resp = await dio.post("/gc/login",
        data: {DatabaseRecords.useremail: userData[DatabaseRecords.useremail]});
    var data = resp.data!;
    if (data["success"] == true) {
      commStore.setAdminNone();
      Map<String, bool> authCompetitions = {
        "spardha": false,
        "kriti": false,
        "manthan": false,
        "sahyog": false
      };
      data[DatabaseRecords.authevents].forEach((element) => {
            authCompetitions[element] = true,
            if (element == "spardha")
              {commStore.setSpardhaAdmin(true)}
            else if (element == "kriti")
              {commStore.setKritiAdmin(true)}
            else if (element == "manthan")
              {commStore.setManthanAdmin(true)}
            else if (element == "sahyog")
              {commStore.setSahyogAdmin(true)}
          });
      await AuthUserHelpers.saveAuthCompetitions(authCompetitions);
      await AuthUserHelpers.setAdmin(data[DatabaseRecords.isadmin]);
      await AuthUserHelpers.setAccessToken(data[DatabaseRecords.accesstoken]);
      await AuthUserHelpers.setRefreshToken(data[DatabaseRecords.refreshtoken]);
    }
  }

  Future<bool> regenerateAccessToken() async {
    String refreshToken = await AuthUserHelpers.getRefreshToken();
    try {
      Dio regenDio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('SERVER-URL'),
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            'Security-Key': const String.fromEnvironment('SECURITY-KEY')
          }));
      Response<Map<String, dynamic>> resp = await regenDio.post(
          "/gc/gen-accesstoken",
          options: Options(headers: {"authorization": "Bearer $refreshToken"}));
      var data = resp.data!;
      await AuthUserHelpers.setAccessToken(data["token"]);
      return true;
    } catch (err) {
      return false;
    }
  }

  Future<List<SpardhaEventModel>> getSpardhaSchedule(ViewType v) async {
    try {
      if (v == ViewType.admin) {
        dio.options.queryParameters["forAdmin"] = "true";
      }
      Response resp = await dio.get("/gc/spardha/event-schedule");
      List<SpardhaEventModel> output = [];
      for (var e in List<dynamic>.from(resp.data["details"])) {
        {
          output.add(SpardhaEventModel.fromJson(e));
        }
      }
      return output;
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<List<KritiEventModel>> getKritiSchedule(ViewType v) async {
    try {
      if (v == ViewType.admin) {
        dio.options.queryParameters["forAdmin"] = "true";
      }
      Response resp = await dio.get("/gc/kriti/event-schedule");
      List<KritiEventModel> output = [];
      for (var e in List<dynamic>.from(resp.data["details"])) {
        {
          output.add(KritiEventModel.fromJson(e));
        }
      }
      return output;
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<List<ManthanEventModel>> getManthanSchedule(ViewType v) async {
    try {
      if (v == ViewType.admin) {
        dio.options.queryParameters["forAdmin"] = "true";
      }
      Response resp = await dio.get("/gc/manthan/event-schedule");
      List<ManthanEventModel> output = [];
      for (var e in List<dynamic>.from(resp.data["details"])) {
        {
          output.add(ManthanEventModel.fromJson(e));
        }
      }
      return output;
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<List<SahyogEventModel>> getSahyogSchedule(ViewType v) async {
    try {
      if (v == ViewType.admin) {
        dio.options.queryParameters["forAdmin"] = "true";
      }
      Response resp = await dio.get("/gc/sahyog/event-schedule");
      List<SahyogEventModel> output = [];
      for (var e in List<dynamic>.from(resp.data["details"])) {
        {
          output.add(SahyogEventModel.fromJson(e));
        }
      }
      return output;
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<List<SpardhaEventModel>> getSpardhaResults(ViewType v) async {
    try {
      if (v == ViewType.admin) {
        dio.options.queryParameters["forAdmin"] = "true";
      }
      Response resp = await dio.get("/gc/spardha/event-schedule/results");
      List<SpardhaEventModel> output = [];
      for (var e in List<dynamic>.from(resp.data["details"])) {
        {
          output.add(SpardhaEventModel.fromJson(e));
        }
      }
      return output;
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<List<KritiEventModel>> getKritiResults(ViewType v) async {
    try {
      if (v == ViewType.admin) {
        dio.options.queryParameters["forAdmin"] = "true";
      }
      Response resp = await dio.get("/gc/kriti/event-schedule/results");
      List<KritiEventModel> output = [];
      for (var e in List<dynamic>.from(resp.data["details"])) {
        {
          output.add(KritiEventModel.fromJson(e));
        }
      }
      return output;
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<List<ManthanEventModel>> getManthanResults(ViewType v) async {
    try {
      if (v == ViewType.admin) {
        dio.options.queryParameters["forAdmin"] = "true";
      }
      Response resp = await dio.get("/gc/manthan/event-schedule/results");
      List<ManthanEventModel> output = [];
      for (var e in List<dynamic>.from(resp.data["details"])) {
        {
          output.add(ManthanEventModel.fromJson(e));
        }
      }
      return output;
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<List<SahyogEventModel>> getSahyogResults(ViewType v) async {
    try {
      if (v == ViewType.admin) {
        dio.options.queryParameters["forAdmin"] = "true";
      }
      Response resp = await dio.get("/gc/sahyog/event-schedule/results");
      List<SahyogEventModel> output = [];
      for (var e in List<dynamic>.from(resp.data["details"])) {
        {
          output.add(SahyogEventModel.fromJson(e));
        }
      }
      return output;
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<void> addUpdateSpardhaResult(String eventID, List<List<SpardhaResultModel>> data,
      String victoryStatement) async {
    try {
      List<List<Map>> results = [];
      for (var positionResults in data) {
        List<Map> addResults = [];
        for (var result in positionResults) {
          addResults.add(result.toJson());
        }
        results.add(addResults);
      }
      Response resp = await dio.patch(
          '/gc/spardha/event-schedule/result/$eventID',
          data: {'victoryStatement': victoryStatement, 'results': results});
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<void> addUpdateKritiResult(String eventID, List<KritiResultModel> data,
      String victoryStatement) async {
    try {
      List<Map> results = [];
      for (var positionResults in data) {
        results.add(positionResults.toJson());
      }
      Response resp = await dio.patch(
          '/gc/kriti/event-schedule/result/$eventID',
          data: {'victoryStatement': victoryStatement, 'results': results});
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<void> addUpdateManthanResult(String eventID, List<ManthanResultModel> data,
      String victoryStatement) async {
    try {
      List<Map> results = [];
      for (var positionResults in data) {
        results.add(positionResults.toJson());
      }
      Response resp = await dio.patch(
          '/gc/manthan/event-schedule/result/$eventID',
          data: {'victoryStatement': victoryStatement, 'results': results});
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<void> addUpdateSahyogResult(String eventID,
      List<SahyogResultModel> data, String victoryStatement) async {
    try {
      List<Map> results = [];
      for (var positionResults in data) {
        results.add(positionResults.toJson());
      }
      Response resp = await dio.patch(
          '/gc/sahyog/event-schedule/result/$eventID',
          data: {'victoryStatement': victoryStatement, 'results': results});
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<void> postSpardhaStanding(Map<String, dynamic> data) async {
    try {
      Response resp = await dio.post("/gc/spardha/standings", data: data);
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<void> updateSpardhaStanding(StandingModel standingModel) async {
    try {
      Response resp = await dio.patch(
          "/gc/spardha/standings/${standingModel.id}",
          data: standingModel.toJson());
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  Future<bool> deleteSpardhaStanding(String standingID) async {
    try {
      Response resp = await dio.delete("/gc/spardha/standings/$standingID");
      return resp.data['success'];
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  // Get-all events

  Future<List<String>> getCompetitionEvents({required String competition}) async {
    try {
      Response resp = await dio.get("/gc/$competition/all-events");
      return List<String>.from(resp.data["details"]);
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  // Get GC Standings

  Future<List<dynamic>> getGCStandings() async {
    try {
      Response resp = await dio.get("/gc/overall/standings");
      return resp.data['details'];
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  //Get Competition standings

  Future<Map<String, dynamic>> getStandings({required String competition}) async {
    try {
      Response resp1 = await dio.get("/gc/$competition/standings/all-events");
      Response resp2 = await dio.get("/gc/$competition/standings");
      return {
        "overall": resp2.data["details"],
        "event-wise": resp1.data["details"]
      };
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  //Post Event Schedule
  Future<void> postEventSchedule({required Map<String, dynamic> data, required String competiton}) async {
    try {
      var resp = await dio.post("/gc/$competiton/event-schedule", data: data);
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  //update an event

  Future<void> updateEventSchedule({required Map<String,dynamic> data, required String competition}) async {
    try {
      Response resp = await dio.patch('/gc/$competition/event-schedule/${data['_id']}',
          data: data);
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  //delete event

  Future<void> deleteEvent({required String eventID, required String competition}) async {
    try {
      Response resp = await dio.delete('/gc/$competition/event-schedule/$eventID');
    } on DioError catch (err) {
      return Future.error(err);
    }
  }

  //delete result

  Future<void> deleteResult({required String eventID, required String competition}) async {
    try {
      await dio.delete('/gc/$competition/event-schedule/result/$eventID');
    } on DioError catch (err) {
      return Future.error(err);
    }
  }


}
