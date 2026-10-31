import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'strings_en.dart';
import 'strings_it.dart';
import 'strings_es.dart';
import 'strings_fr.dart';
import 'strings_de.dart';
import 'strings_pt.dart';
import 'strings_zh.dart';

/// Supported application languages.
enum AppLanguage {
  en('en', 'English', '🇬🇧'),
  it('it', 'Italiano', '🇮🇹'),
  es('es', 'Español', '🇪🇸'),
  fr('fr', 'Français', '🇫🇷'),
  de('de', 'Deutsch', '🇩🇪'),
  pt('pt', 'Português', '🇵🇹'),
  zh('zh', '中文', '🇨🇳');

  final String code;
  final String label;
  final String flag;

  const AppLanguage(this.code, this.label, this.flag);

  static const AppLanguage fallback = AppLanguage.en;

  static AppLanguage? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final normalized = code.toLowerCase().split(RegExp(r'[-_]')).first;
    for (final lang in AppLanguage.values) {
      if (lang.code == normalized) return lang;
    }
    return null;
  }

  static AppLanguage resolve({String? overrideCode, Locale? systemLocale}) {
    if (overrideCode != null && overrideCode.isNotEmpty) {
      final overrideLang = fromCode(overrideCode);
      if (overrideLang != null) return overrideLang;
    }

    final sysCode = systemLocale?.languageCode ??
        PlatformDispatcher.instance.locale.languageCode;
    return fromCode(sysCode) ?? fallback;
  }
}

class AppLocalizations {
  final AppLanguage language;
  final Map<String, String> _map;

  AppLocalizations(this.language) : _map = _getMap(language);

  static Map<String, String> _getMap(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.it:
        return stringsIt;
      case AppLanguage.es:
        return stringsEs;
      case AppLanguage.fr:
        return stringsFr;
      case AppLanguage.de:
        return stringsDe;
      case AppLanguage.pt:
        return stringsPt;
      case AppLanguage.zh:
        return stringsZh;
      case AppLanguage.en:
        return stringsEn;
    }
  }

  String _t(String key) => _map[key] ?? stringsEn[key] ?? key;

  String _tParams(String key, Map<String, Object> params) {
    var text = _t(key);
    params.forEach((k, v) {
      text = text.replaceAll('{$k}', v.toString());
    });
    return text;
  }

  static AppLocalizations of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return AppLocalizations(AppLanguage.resolve(systemLocale: locale));
  }

  String get appTitle => 'Keep in Mind';
  String get navLibrary => _t('navLibrary');
  String get navWidget => _t('navWidget');
  String get navAppAndExport => _t('navAppAndExport');
  String get badgeLocal => _t('badgeLocal');
  String get searchHint => _t('searchHint');
  String get clearSearchTooltip => _t('clearSearchTooltip');
  String get filterAll => _t('filterAll');
  String get filterPinned => _t('filterPinned');

  String get typeLink => _t('typeLink');
  String get typeText => _t('typeText');
  String get typeImage => _t('typeImage');
  String get typeAudio => _t('typeAudio');
  String get typeFile => _t('typeFile');

  String typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'link':
        return typeLink;
      case 'image':
      case 'immagine':
        return typeImage;
      case 'audio':
        return typeAudio;
      case 'file':
        return typeFile;
      case 'text':
      case 'nota':
      default:
        return typeText;
    }
  }

  String tagLabel(String tag) {
    final clean = tag.trim().toLowerCase();
    switch (clean) {
      case 'link':
        return typeLink;
      case 'nota':
      case 'text':
      case 'note':
        return typeText;
      case 'immagine':
      case 'image':
        return typeImage;
      case 'audio':
        return typeAudio;
      case 'file':
        return typeFile;
      default:
        if (clean.isEmpty) return '';
        return clean[0].toUpperCase() + clean.substring(1);
    }
  }

  String get emptyStateTitle => _t('emptyStateTitle');
  String get emptyStateSubtitle => _t('emptyStateSubtitle');

  String get actionAdd => _t('actionAdd');
  String get actionSave => _t('actionSave');
  String get actionSaving => _t('actionSaving');
  String get actionCancel => _t('actionCancel');
  String get actionDelete => _t('actionDelete');
  String get actionEdit => _t('actionEdit');
  String get actionSaveDone => _t('actionSaveDone');
  String get actionOpen => _t('actionOpen');
  String get actionShare => _t('actionShare');
  String get actionReshare => _t('actionReshare');
  String get actionCopy => _t('actionCopy');
  String get actionRemove => _t('actionRemove');
  String get actionBack => _t('actionBack');

  String get tooltipPin => _t('tooltipPin');
  String get tooltipUnpin => _t('tooltipUnpin');
  String get tooltipCopyContent => _t('tooltipCopyContent');
  String get tooltipReshare => _t('tooltipReshare');
  String get tooltipDeleteFromMemory => _t('tooltipDeleteFromMemory');
  String get tooltipOpenLink => _t('tooltipOpenLink');
  String get tooltipPasteClipboard => _t('tooltipPasteClipboard');
  String get tooltipRemoveAttachment => _t('tooltipRemoveAttachment');
  String get tooltipAddMemory => _t('tooltipAddMemory');

  String get copiedToClipboard => _t('copiedToClipboard');
  String get changesSaved => _t('changesSaved');
  String get deleteConfirmTitle => _t('deleteConfirmTitle');

  String deleteConfirmMessage(String title) =>
      _tParams('deleteConfirmMessage', {'title': title});

  String savedInKeepInMind(String type, String title) =>
      _tParams('savedInKeepInMind', {'type': type, 'title': title});

  String cannotOpenLink(String url) =>
      _tParams('cannotOpenLink', {'url': url});

  String cannotOpenAttachment(String name) =>
      _tParams('cannotOpenAttachment', {'name': name});

  String fileTooBigError(Object maxMb) =>
      _tParams('fileTooBigError', {'maxMb': maxMb.toString()});

  String get addSheetTitle => _t('addSheetTitle');
  String get addSheetSubtitle => _t('addSheetSubtitle');
  String get inputTitleLabel => _t('inputTitleLabel');
  String get inputTitleHint => _t('inputTitleHint');
  String get inputContentLabel => _t('inputContentLabel');
  String get inputContentHint => _t('inputContentHint');
  String get createNewTagHint => _t('createNewTagHint');
  String get btnAddTag => _t('btnAddTag');
  String get pinThisItem => _t('pinThisItem');
  String get pinSubtitle => _t('pinSubtitle');
  String get btnPhoto => _t('btnPhoto');
  String get btnVideo => _t('btnVideo');
  String get btnRecordAudio => _t('btnRecordAudio');
  String get btnStopAudio => _t('btnStopAudio');
  String get btnAttachFile => _t('btnAttachFile');
  String get errorNoEmptyItem => _t('errorNoEmptyItem');
  String get audioMaxDurationReached => _t('audioMaxDurationReached');

  String get detailTitle => _t('detailTitle');
  String get detailSectionContent => _t('detailSectionContent');
  String get detailSectionTags => _t('detailSectionTags');
  String get detailSectionAttachment => _t('detailSectionAttachment');
  String get detailSectionInfo => _t('detailSectionInfo');
  String get audioRecordingLabel => _t('audioRecordingLabel');
  String get videoAttachmentLabel => _t('videoAttachmentLabel');
  String get fileAttachmentLabel => _t('fileAttachmentLabel');
  String get imageNotAvailable => _t('imageNotAvailable');
  String get btnOpenExternal => _t('btnOpenExternal');
  String get btnOpenBrowser => _t('btnOpenBrowser');
  String get btnShareFile => _t('btnShareFile');
  String get infoSavedOn => _t('infoSavedOn');
  String get infoSource => _t('infoSource');
  String get infoPath => _t('infoPath');

  String get widgetPreviewTitle => _t('widgetPreviewTitle');
  String get widgetQuickAdd => _t('widgetQuickAdd');
  String get widgetViewAll => _t('widgetViewAll');
  String get widgetEmptyMessage => _t('widgetEmptyMessage');

  String widgetPreviewSubtitle(int count) =>
      _tParams('widgetPreviewSubtitle', {'count': count});

  String widgetLatestCount(int current, int max) =>
      _tParams('widgetLatestCount', {'current': current, 'max': max});

  String widgetLocalMemorySubtitle(int total) =>
      _tParams('widgetLocalMemorySubtitle', {'total': total});

  String get widgetConfigCardTitle => _t('widgetConfigCardTitle');
  String get widgetConfigItemsCount => _t('widgetConfigItemsCount');
  String get widgetConfigPrioritizePinned => _t('widgetConfigPrioritizePinned');
  String get widgetConfigPrioritizePinnedSubtitle => _t('widgetConfigPrioritizePinnedSubtitle');
  String get widgetConfigShowTags => _t('widgetConfigShowTags');
  String get widgetConfigShowTagsSubtitle => _t('widgetConfigShowTagsSubtitle');
  String get widgetConfigFilterBy => _t('widgetConfigFilterBy');
  String get widgetHowToTitle => _t('widgetHowToTitle');
  String get widgetHowToInstructions => _t('widgetHowToInstructions');

  String get languageSettingsTitle => _t('languageSettingsTitle');
  String get languageSettingsSubtitle => _t('languageSettingsSubtitle');
  String get languageAutoSystem => _t('languageAutoSystem');

  String languageCurrentAuto(String resolvedName) =>
      _tParams('languageCurrentAuto', {'resolvedName': resolvedName});

  String get statisticsCardTitle => _t('statisticsCardTitle');
  String get statTotalSaved => _t('statTotalSaved');
  String get statPinned => _t('statPinned');
  String get statCustomTags => _t('statCustomTags');

  String get preferencesCardTitle => _t('preferencesCardTitle');
  String get prefConfirmDelete => _t('prefConfirmDelete');
  String get prefConfirmDeleteSubtitle => _t('prefConfirmDeleteSubtitle');
  String get prefMaxAudioDuration => _t('prefMaxAudioDuration');
  String get prefMaxFileSize => _t('prefMaxFileSize');
  String get prefAudioNoLimitWarning => _t('prefAudioNoLimitWarning');
  String get optionNoLimit => _t('optionNoLimit');

  String get backupCardTitle => _t('backupCardTitle');
  String get backupDescription => _t('backupDescription');
  String get btnExportJson => _t('btnExportJson');
  String get btnCopyJson => _t('btnCopyJson');
  String get btnImportJson => _t('btnImportJson');
  String get btnClearAll => _t('btnClearAll');

  String get importDialogTitle => _t('importDialogTitle');
  String get importDialogInstruction => _t('importDialogInstruction');
  String get btnChooseFile => _t('btnChooseFile');
  String get importPasteHint => _t('importPasteHint');
  String get btnConfirmImport => _t('btnConfirmImport');
  String get importEmptyOrInvalidError => _t('importEmptyOrInvalidError');

  String importSuccessMessage(int added, int merged) =>
      _tParams('importSuccessMessage', {'added': added, 'merged': merged});

  String get clearAllDialogTitle => _t('clearAllDialogTitle');
  String get clearAllDialogMessage => _t('clearAllDialogMessage');
  String get allDataCleared => _t('allDataCleared');

  String get creditsCardTitle => _t('creditsCardTitle');
  String get creditsDescription => _t('creditsDescription');
  String get coffeeOption1 => _t('coffeeOption1');
  String get coffeeOption2 => _t('coffeeOption2');
  String get coffeeOption3 => _t('coffeeOption3');

  String coffeeThanks(String label) =>
      _tParams('coffeeThanks', {'label': label});

  String get welcomeLinkTitle => _t('welcomeLinkTitle');
  String get welcomeLinkContent => _t('welcomeLinkContent');
  String get welcomeTextTitle => _t('welcomeTextTitle');
  String get welcomeTextContent => _t('welcomeTextContent');

  String get shareTestToolsTitle => _t('shareTestToolsTitle');
  String get btnSimulateShareLink => _t('btnSimulateShareLink');
  String get btnSimulateShareNote => _t('btnSimulateShareNote');
  String get simulatedLinkSubject => _t('simulatedLinkSubject');
  String get simulatedNoteSubject => _t('simulatedNoteSubject');
  String get simulatedNoteText => _t('simulatedNoteText');
  String get simulatedShareSource => _t('simulatedShareSource');
  String get actionClose => _t('actionClose');
  String get actionPaste => _t('actionPaste');
  String get coffeeDialogBody => _t('coffeeDialogBody');
  String get defaultPhotoTitle => _t('defaultPhotoTitle');
  String get cameraError => _t('cameraError');
  String get audioSaveError => _t('audioSaveError');
  String get micPermissionDenied => _t('micPermissionDenied');
  String get filePickError => _t('filePickError');
  String get tagInvalidCharsError => _t('tagInvalidCharsError');
  String get tagMaxLengthError => _t('tagMaxLengthError');
  String get attachmentRemovedNotice => _t('attachmentRemovedNotice');

  String symbolicSupportLabel(String price) =>
      _tParams('symbolicSupportLabel', {'price': price});

  String defaultVoiceNoteTitle(int durationSec) =>
      _tParams('defaultVoiceNoteTitle', {'durationSec': durationSec});

  String audioMaxDurationSaved(String limitLabel) =>
      _tParams('audioMaxDurationSaved', {'limitLabel': limitLabel});

  String audioPlaybackError(String error) =>
      _tParams('audioPlaybackError', {'error': error});

  String videoPlayerTapHint(String title) =>
      _tParams('videoPlayerTapHint', {'title': title});

}


