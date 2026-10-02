import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/data/memory_repository.dart';
import 'package:reminder/data/settings_store.dart';
import 'package:reminder/services/backup_service.dart';

import 'support/fakes.dart';

void main() {
  test('export -> validate -> restore round trip', () async {
    final rig = TestRig(
      settings: testSettings(school: <String, int>{'tue_a_end': 900}),
    );
    await rig.engine.setDone('sat-01', DateTime.utc(2026, 9, 26), true);
    await rig.engine.setDone('sun-02', DateTime.utc(2026, 9, 27), true);
    final text = await BackupService.export(rig.repo, rig.store);

    final data = BackupService.parse(text);
    expect(data.activities.length, 108);
    expect(data.completions.length, 2);
    expect(data.settings.schoolTimes['tue_a_end'], 900);

    final repo2 = InMemoryActivityRepository();
    final store2 = MemorySettingsStore();
    await BackupService.apply(data, repo2, store2);
    final a1 = (await rig.repo.getActivities()).map((a) => a.toMap()).toList();
    final a2 = (await repo2.getActivities()).map((a) => a.toMap()).toList();
    expect(a2, a1);
    expect(await repo2.completedIdsOn('2026-09-26'), {'sat-01'});
    expect(await repo2.completedIdsOn('2026-09-27'), {'sun-02'});
    expect(store2.settings.toJson(), rig.store.settings.toJson());
  });

  test('invalid backups are rejected before anything is written', () async {
    final rig = TestRig();
    final good = jsonDecode(await BackupService.export(rig.repo, rig.store))
        as Map<String, dynamic>;

    expect(
      () => BackupService.parse('not json'),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => BackupService.parse(jsonEncode(<String, Object>{'format': 'x'})),
      throwsA(isA<BackupFormatException>()),
    );

    final dupe = Map<String, dynamic>.from(good);
    final acts = List<dynamic>.from(good['activities'] as List);
    acts.add(acts.first);
    dupe['activities'] = acts;
    expect(
      () => BackupService.parse(jsonEncode(dupe)),
      throwsA(isA<BackupFormatException>()),
    );

    final badDay = Map<String, dynamic>.from(good);
    final acts2 = List<dynamic>.from(good['activities'] as List);
    acts2[0] = Map<String, dynamic>.from(acts2[0] as Map)..['day'] = 9;
    badDay['activities'] = acts2;
    expect(
      () => BackupService.parse(jsonEncode(badDay)),
      throwsA(isA<BackupFormatException>()),
    );

    final badSettings = Map<String, dynamic>.from(good);
    badSettings['settings'] = Map<String, dynamic>.from(
      good['settings'] as Map,
    )..['leadMinutes'] = 7;
    expect(
      () => BackupService.parse(jsonEncode(badSettings)),
      throwsA(isA<BackupFormatException>()),
    );

    // Original data untouched.
    expect((await rig.repo.getActivities()).length, 108);
  });
}
