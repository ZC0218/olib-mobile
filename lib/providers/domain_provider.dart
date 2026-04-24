import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hive_service.dart';
import '../services/zlibrary_api.dart';
import 'zlibrary_provider.dart';

/// All available mirror domains (flat list).
final domainListProvider = Provider<List<String>>((ref) {
  return const [
    '101w.ru',
    'intcn.online',
    '2001.ru',
    'opendelta.org',
    '07210127.xyz',
    '101l.online',
    '101o.online',
    '160205.xyz',
    '191954.online',
    '20220303.xyz',
    '021128.xyz',
    '404114.xyz',
    '553211.xyz',
    '817523.xyz',
    '9libmirror.tech',
    'anthology.christmas',
    'anthology.lol',
    'archive.christmas',
    'archive.college',
    'bibliotheca.best',
    'bibliotheca.christmas',
    'bibliotheca.digital',
    'book.christmas',
    'bookroom.digital',
    'bookroom.monster',
    'bookroom.study',
    'bookroom.wtf',
    'bookworm.monster',
    'catalog.monster',
    'catalog.quest',
    'chishui.online',
    'desuwa.me',
    'dhiti.tech',
    'elaborate.monster',
    'elaborate.quest',
    'elaborate.wtf',
    'elaboratethinking.site',
    'fbiwarning.online',
    'free2read.cc',
    'freebooks.lol',
    'freedomain.top',
    'gopee.monster',
    'haechi.com',
    'interflow.ch',
    'ireadhuang.sbs',
    'meuslivros.online',
    'niulangshan.online',
    'pkuedu.online',
    'qiushi1024.com',
    'webbox.cool',
    'weblib.xyz',
    'ws95.pw',
    'xitler.cyou',
    'z-li.top',
    'z8341.online',
    'zlibdie.online',
    'zlibraryb.online',
    'zlibrary9.online',
  ];
});

final domainProvider = StateNotifierProvider<DomainNotifier, String>((ref) {
  final api = ref.watch(zlibraryApiProvider);
  return DomainNotifier(api);
});

class DomainNotifier extends StateNotifier<String> {
  final ZLibraryApi _api;

  DomainNotifier(this._api)
      : super(HiveService.settingsBox.get('domain', defaultValue: 'pkuedu.online')) {
    // Ensure API is in sync with initial state
    _api.setDomain(state);
  }

  void setDomain(String domain) {
    state = domain;
    HiveService.settingsBox.put('domain', domain);
    _api.setDomain(domain);
  }
  
  void setCustomDomain(String domain) {
    // Remove protocol if present
    String cleanDomain = domain.replaceAll(RegExp(r'^https?://'), '');
    if (cleanDomain.endsWith('/')) {
      cleanDomain = cleanDomain.substring(0, cleanDomain.length - 1);
    }
    setDomain(cleanDomain);
  }
}
