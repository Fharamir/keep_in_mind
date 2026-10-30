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
      default:
        return stringsEn;
    }
  }

  String _t(String key) => _map[key] ?? stringsEn[key] ?? key;

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

  String deleteConfirmMessage(String title) {
    switch (language) {
      case AppLanguage.it:
        return 'Vuoi eliminare definitivamente "$title"?';
      case AppLanguage.es:
        return '¿Seguro que deseas eliminar definitivamente "$title"?';
      case AppLanguage.fr:
        return 'Voulez-vous vraiment supprimer définitivement "$title" ?';
      case AppLanguage.de:
        return 'Möchten Sie "$title" wirklich dauerhaft löschen?';
      case AppLanguage.pt:
        return 'Tem certeza de que deseja excluir permanentemente "$title"?';
      case AppLanguage.zh:
        return '您确定要永久删除“$title”吗？';
      case AppLanguage.en:
      default:
        return 'Are you sure you want to permanently delete "$title"?';
    }
  }

  String savedInKeepInMind(String type, String title) {
    switch (language) {
      case AppLanguage.it:
        return 'Salvato in Keep in Mind ($type): "$title"';
      case AppLanguage.es:
        return 'Guardado en Keep in Mind ($type): "$title"';
      case AppLanguage.fr:
        return 'Enregistré dans Keep in Mind ($type) : "$title"';
      case AppLanguage.de:
        return 'In Keep in Mind gespeichert ($type): "$title"';
      case AppLanguage.pt:
        return 'Salvo no Keep in Mind ($type): "$title"';
      case AppLanguage.zh:
        return '已保存到 Keep in Mind ($type): "$title"';
      case AppLanguage.en:
      default:
        return 'Saved to Keep in Mind ($type): "$title"';
    }
  }

  String cannotOpenLink(String url) {
    switch (language) {
      case AppLanguage.it:
        return 'Impossibile aprire il link: $url';
      case AppLanguage.es:
        return 'No se puede abrir el enlace: $url';
      case AppLanguage.fr:
        return 'Impossible d\'ouvrir le lien : $url';
      case AppLanguage.de:
        return 'Link kann nicht geöffnet werden: $url';
      case AppLanguage.pt:
        return 'Não foi possível abrir o link: $url';
      case AppLanguage.zh:
        return '无法打开链接: $url';
      case AppLanguage.en:
      default:
        return 'Unable to open link: $url';
    }
  }

  String cannotOpenAttachment(String name) {
    switch (language) {
      case AppLanguage.it:
        return 'Impossibile aprire il file: $name';
      case AppLanguage.es:
        return 'No se puede abrir el archivo: $name';
      case AppLanguage.fr:
        return 'Impossible d\'ouvrir le fichier : $name';
      case AppLanguage.de:
        return 'Datei kann nicht geöffnet werden: $name';
      case AppLanguage.pt:
        return 'Não foi possível abrir o arquivo: $name';
      case AppLanguage.zh:
        return '无法打开文件: $name';
      case AppLanguage.en:
      default:
        return 'Unable to open file: $name';
    }
  }

  String fileTooBigError(String maxMb) {
    switch (language) {
      case AppLanguage.it:
        return 'Il file selezionato supera la dimensione massima consentita di $maxMb MB.';
      case AppLanguage.es:
        return 'El archivo seleccionado supera el tamaño máximo permitido de $maxMb MB.';
      case AppLanguage.fr:
        return 'Le fichier sélectionné dépasse la taille maximale autorisée de $maxMb MB.';
      case AppLanguage.de:
        return 'Die ausgewählte Datei überschreitet die maximale Größe von $maxMb MB.';
      case AppLanguage.pt:
        return 'O arquivo selecionado excede o tamanho máximo permitido de $maxMb MB.';
      case AppLanguage.zh:
        return '所选文件超过了允许的最大大小 $maxMb MB。';
      case AppLanguage.en:
      default:
        return 'The selected file exceeds the maximum allowed size of $maxMb MB.';
    }
  }

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

  String widgetPreviewSubtitle(int count) {
    switch (language) {
      case AppLanguage.it:
        return 'Ecco come appare il widget Keep in Mind sulla schermata Home del dispositivo con gli ultimi $count contenuti:';
      case AppLanguage.es:
        return 'Así se ve el widget Keep in Mind en la pantalla de inicio con los últimos $count elementos:';
      case AppLanguage.fr:
        return 'Voici comment apparaît le widget Keep in Mind sur l\'écran d\'accueil avec les $count derniers éléments :';
      case AppLanguage.de:
        return 'So sieht das Keep in Mind-Widget mit den letzten $count Inhalten aus:';
      case AppLanguage.pt:
        return 'Veja como o widget Keep in Mind aparece na tela inicial com os últimos $count itens:';
      case AppLanguage.zh:
        return '以下是包含最新 $count 条内容的 Keep in Mind 主屏微件外观：';
      case AppLanguage.en:
      default:
        return 'Here is how Keep in Mind looks on the home screen with the latest $count items:';
    }
  }

  String widgetLatestCount(int current, int max) {
    switch (language) {
      case AppLanguage.it:
        return 'Ultimi $current/$max';
      case AppLanguage.es:
        return 'Últimos $current/$max';
      case AppLanguage.fr:
        return 'Derniers $current/$max';
      case AppLanguage.de:
        return 'Neueste $current/$max';
      case AppLanguage.pt:
        return 'Últimos $current/$max';
      case AppLanguage.zh:
        return '最新 $current/$max';
      case AppLanguage.en:
      default:
        return 'Latest $current/$max';
    }
  }

  String widgetLocalMemorySubtitle(int total) {
    switch (language) {
      case AppLanguage.it:
        return 'Memoria locale · $total salvati';
      case AppLanguage.es:
        return 'Memoria local · $total guardados';
      case AppLanguage.fr:
        return 'Mémoire locale · $total enregistrés';
      case AppLanguage.de:
        return 'Lokaler Speicher · $total gespeichert';
      case AppLanguage.pt:
        return 'Armazenamento local · $total salvos';
      case AppLanguage.zh:
        return '本地存储 · 已存 $total 项';
      case AppLanguage.en:
      default:
        return 'Local storage · $total saved';
    }
  }

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

  String languageCurrentAuto(String resolvedName) {
    switch (language) {
      case AppLanguage.it:
        return 'Predefinita di sistema ($resolvedName)';
      case AppLanguage.es:
        return 'Predeterminado del sistema ($resolvedName)';
      case AppLanguage.fr:
        return 'Par défaut du système ($resolvedName)';
      case AppLanguage.de:
        return 'Systemstandard ($resolvedName)';
      case AppLanguage.pt:
        return 'Padrão do sistema ($resolvedName)';
      case AppLanguage.zh:
        return '系统默认 ($resolvedName)';
      case AppLanguage.en:
      default:
        return 'System default ($resolvedName)';
    }
  }

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

  String importSuccessMessage(int added, int merged) {
    switch (language) {
      case AppLanguage.it:
        return 'Importazione completata: $added nuovi elementi, $merged tag aggiornati.';
      case AppLanguage.es:
        return 'Importación completada: $added elementos nuevos, $merged etiquetas actualizadas.';
      case AppLanguage.fr:
        return 'Importation terminée : $added nouveaux éléments, $merged étiquettes mises à jour.';
      case AppLanguage.de:
        return 'Import abgeschlossen: $added neue Inhalte, $merged Tags aktualisiert.';
      case AppLanguage.pt:
        return 'Importação concluída: $added novos itens, $merged etiquetas atualizadas.';
      case AppLanguage.zh:
        return '导入完成：新增 $added 条内容，更新 $merged 个标签。';
      case AppLanguage.en:
      default:
        return 'Import completed: $added new items, $merged updated tags.';
    }
  }

  String get clearAllDialogTitle => _t('clearAllDialogTitle');
  String get clearAllDialogMessage => _t('clearAllDialogMessage');
  String get allDataCleared => _t('allDataCleared');

  String get creditsCardTitle => _t('creditsCardTitle');
  String get creditsDescription => _t('creditsDescription');
  String get coffeeOption1 => _t('coffeeOption1');
  String get coffeeOption2 => _t('coffeeOption2');
  String get coffeeOption3 => _t('coffeeOption3');

  String coffeeThanks(String label) {
    switch (language) {
      case AppLanguage.it:
        return 'Grazie infinite per il tuo supporto ($label)! ❤️';
      case AppLanguage.es:
        return '¡Muchas gracias por tu apoyo ($label)! ❤️';
      case AppLanguage.fr:
        return 'Merci infiniment pour votre soutien ($label) ! ❤️';
      case AppLanguage.de:
        return 'Vielen Dank für Ihre Unterstützung ($label)! ❤️';
      case AppLanguage.pt:
        return 'Muito obrigado pelo seu apoio ($label)! ❤️';
      case AppLanguage.zh:
        return '非常感谢您的支持 ($label)！❤️';
      case AppLanguage.en:
      default:
        return 'Thank you for your support ($label)! ❤️';
    }
  }

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

  String symbolicSupportLabel(String price) {
    switch (language) {
      case AppLanguage.it:
        return 'Supporto simbolico: $price';
      case AppLanguage.es:
        return 'Apoyo simbólico: $price';
      case AppLanguage.fr:
        return 'Soutien symbolique : $price';
      case AppLanguage.de:
        return 'Symbolische Unterstützung: $price';
      case AppLanguage.pt:
        return 'Apoio simbólico: $price';
      case AppLanguage.zh:
        return '支持金额: $price';
      case AppLanguage.en:
      default:
        return 'Symbolic support: $price';
    }
  }

  String defaultVoiceNoteTitle(int durationSec) {
    switch (language) {
      case AppLanguage.it:
        return 'Nota vocale (${durationSec}s)';
      case AppLanguage.es:
        return 'Nota de voz (${durationSec}s)';
      case AppLanguage.fr:
        return 'Note vocale (${durationSec}s)';
      case AppLanguage.de:
        return 'Sprachnotiz (${durationSec}s)';
      case AppLanguage.pt:
        return 'Nota de voz (${durationSec}s)';
      case AppLanguage.zh:
        return '语音笔记 (${durationSec}秒)';
      case AppLanguage.en:
      default:
        return 'Voice note (${durationSec}s)';
    }
  }

  String audioMaxDurationSaved(String limitLabel) {
    switch (language) {
      case AppLanguage.it:
        return 'Raggiunto il limite massimo di $limitLabel: registrazione salvata.';
      case AppLanguage.es:
        return 'Se alcanzó el límite máximo de $limitLabel: grabación guardada.';
      case AppLanguage.fr:
        return 'Limite maximale de $limitLabel atteinte : enregistrement sauvegardé.';
      case AppLanguage.de:
        return 'Maximales Limit von $limitLabel erreicht: Aufnahme gespeichert.';
      case AppLanguage.pt:
        return 'Limite máximo de $limitLabel atingido: gravação salva.';
      case AppLanguage.zh:
        return '已达最大时长限制 $limitLabel：录音已自动保存。';
      case AppLanguage.en:
      default:
        return 'Reached maximum limit of $limitLabel: recording saved.';
    }
  }

  String audioPlaybackError(String error) {
    switch (language) {
      case AppLanguage.it:
        return 'Impossibile riprodurre l\'audio: $error';
      case AppLanguage.es:
        return 'No se puede reproducir el audio: $error';
      case AppLanguage.fr:
        return 'Impossible de lire l\'audio : $error';
      case AppLanguage.de:
        return 'Audio kann nicht abgespielt werden: $error';
      case AppLanguage.pt:
        return 'Não foi possível reproduzir o áudio: $error';
      case AppLanguage.zh:
        return '无法播放音频: $error';
      case AppLanguage.en:
      default:
        return 'Unable to play audio: $error';
    }
  }

  String videoPlayerTapHint(String title) {
    switch (language) {
      case AppLanguage.it:
        return '$title (tocca il video per i controlli)';
      case AppLanguage.es:
        return '$title (toca el video para controles)';
      case AppLanguage.fr:
        return '$title (touchez la vidéo pour les commandes)';
      case AppLanguage.de:
        return '$title (Tippen für Steuerung)';
      case AppLanguage.pt:
        return '$title (toque no vídeo para os controles)';
      case AppLanguage.zh:
        return '$title (点击视频以使用控制选项)';
      case AppLanguage.en:
      default:
        return '$title (tap video for controls)';
    }
  }

}


