import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Storage {
  FlutterSecureStorage _storage;
  Map<String, String> _settings = new Map<String, String>();
  get getSettings => _settings;

  Storage() {
    this._storage = new FlutterSecureStorage();
  }
  void resetSettings() {
    this._settings = new Map<String, String>();
  }

  Future<void> initS() async {
    await loadSettings();
  }

  Future<void> loadSettings() async {
    this._settings = await this._storage.readAll();
    //Rprint(this._settings);
  }

  void deleteAll() async {
    await this._storage.deleteAll();
    await loadSettings();
  }

  void addSetting(String key, String value) async {
    print('adding: key: $key, value: $value');
    await this._storage.write(key: key, value: value);
    await loadSettings();
    String succ = this._settings.containsKey(key).toString();
    print("added successfully?: $succ");
  }

  void deleteSetting(String key) async {
    await this._storage.delete(key: key);
    await loadSettings();
  }

  String getSetting(String key) {
    return this._settings[key];
  }

  bool hasSetting(String key) {
    return this._settings.containsKey(key);
  }
}
