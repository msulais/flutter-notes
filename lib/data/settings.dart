import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../enums/settings.dart';

class Settings extends ChangeNotifier {
    static late SharedPreferences prefs;

    final Map<SettingsKey, dynamic> _settings = {
        SettingsKey.useDynamicColor: true,
        SettingsKey.color: Colors.red.value,
        SettingsKey.theme: ThemeMode.system,
        SettingsKey.sortBy: SortBy.title,
        SettingsKey.sortMode: SortMode.ascending
    };

    bool
    get useDynamicColor => _settings[SettingsKey.useDynamicColor];
    set useDynamicColor(bool value) => _update(SettingsKey.useDynamicColor, value);

    Color
    get color => Color(_settings[SettingsKey.color]);
    set color(Color value) => _update(SettingsKey.color, value.value);

    ThemeMode
    get theme => _settings[SettingsKey.theme];
    set theme(ThemeMode value) => _update(SettingsKey.theme, value);

    SortBy
    get sortBy => _settings[SettingsKey.sortBy];
    set sortBy(SortBy value) => _update(SettingsKey.sortBy, value);

    SortMode
    get sortMode => _settings[SettingsKey.sortMode];
    set sortMode(SortMode value) => _update(SettingsKey.sortMode, value);

    void _update(SettingsKey key, dynamic value, [bool notify = true]){
        _settings[key] = value;
        if (notify) notifyListeners();
        Settings.set(key, value);
    }

    Future<void> readFile() async {
        prefs = await SharedPreferences.getInstance();
        try {
            color = Color(Settings.get(SettingsKey.color) ?? Colors.red.value);
            theme = ThemeMode.values.byName(Settings.get(SettingsKey.theme) ?? ThemeMode.system.name);
            useDynamicColor = Settings.get(SettingsKey.useDynamicColor) ?? true;
            sortBy = SortBy.values.byName(Settings.get(SettingsKey.sortBy) ?? SortBy.title.name);
            sortMode = SortMode.values.byName(Settings.get(SettingsKey.sortMode) ?? SortMode.ascending.name);
        } catch (e) {
            debugPrint('ERROR READ FILE SETTINGS: $e');
        }
    }

    static
    dynamic get(SettingsKey key) {
        return prefs.get(key.name);
    }

    /// `value.runtimeType` must be:
    /// * `int`
    /// * `String`
    /// * `bool`
    /// * `double`
    /// * `Enum`
    static
    Future<void> set(SettingsKey key, dynamic value) async {
        if (value is int){
            prefs.setInt(key.name, value);
        }
        else if (value is String){
            prefs.setString(key.name, value);
        }
        else if (value is bool){
            prefs.setBool(key.name, value);
        }
        else if (value is double){
            prefs.setDouble(key.name, value);
        }
        else if (value is Enum){
            prefs.setString(key.name, value.name);
        }
        else {
            debugPrint('Data type not supported [value: $value, value.runtimeType: ${value.runtimeType}]');
        }
    }
}