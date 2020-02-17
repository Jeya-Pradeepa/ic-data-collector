import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catcher/catcher_plugin.dart';

import '../models/user.dart';
import '../configs/configuration.dart';
import '../utils/navigation_service.dart';
import '../utils/route_paths.dart' as routes;
import '../utils/locator.dart';
import '../utils/reporterror.dart';

enum AppState { Idle, Busy }

class AuthModel with ChangeNotifier {
  final NavigationService _navigationService = locator<NavigationService>();
  AppState _state = AppState.Idle;
  AppState get state => _state;
  void setState(AppState appState) {
    _state = appState;
    notifyListeners();
  }

  Future<String> login({User user}) async {
    setState(AppState.Busy);
    String result = "Invalid username or password.";
    try {
      var responce =
          await http.post(Configuration.apiurl + "authentication", body: {
        "strategy": "local",
        "email": user.email.trim(),
        "password": user.password.trim()
      });
      if (responce.statusCode == 201) {
        if (responce.body.isNotEmpty) {
          if (json
                  .decode(responce.body)['user']['mobile_access']
                  .toString()
                  .toLowerCase()
                  .trim() ==
              "yes") {
            saveCurrentLogin(
                responseJson: json.decode(responce.body),
                password: user.password);
            result = "ok";
          } else {
            result = "Sorry, You are not a surveyor";
          }
        }
      }
    } catch (error, stackTrace) {
      result = "Invalid username or password.";
      setState(AppState.Idle);
      ReportError _reporterror = new ReportError();
      _reporterror.systemError = error;
      _reporterror.customError = "Controller:-Auth , method-:login ";
      Catcher.reportCheckedError(_reporterror, stackTrace);
    }
    setState(AppState.Idle);
    notifyListeners();
    return result;
  }

  //if jwt token expired it generate new token
  Future<void> generateRefreshToken() async {
    setState(AppState.Busy);
    try {
      var preferences = await SharedPreferences.getInstance();
      var responce =
          await http.post(Configuration.apiurl + "authentication", body: {
        "strategy": "local",
        "email": preferences.getString('email'),
        "password": preferences.getString('userpass')
      });
      if (responce.statusCode == 201) {
        preferences.setString(
            "accesstoken", json.decode(responce.body)['accessToken']);
      } else {
        _navigationService.navigateRepalceTo(routeName: routes.LoginRoute);
      }
    } catch (error, stackTrace) {
      setState(AppState.Idle);
      ReportError _reporterror = new ReportError();
      _reporterror.systemError = error;
      _reporterror.customError = "Controller:-Auth , method-:generateRefreshToken ";
      Catcher.reportCheckedError(_reporterror, stackTrace);
    }
    setState(AppState.Idle);
  }
}

void saveCurrentLogin({Map responseJson, String password}) async {
  var preferences = await SharedPreferences.getInstance();
  preferences.setString("accesstoken", responseJson['accessToken']);
  preferences.setString("userid", responseJson['user']['_id']);
  preferences.setString("firstname", responseJson['user']['first_name']);
  preferences.setString("lastname", responseJson['user']['last_name']);
  preferences.setString("designation", responseJson['user']['designation']);
  preferences.setString("username", responseJson['user']['user_name']);
  preferences.setString("email", responseJson['user']['email']);
  preferences.setString("activeStatus", responseJson['user']['active_status']);
  preferences.setString("userpass", password.trim());
}
