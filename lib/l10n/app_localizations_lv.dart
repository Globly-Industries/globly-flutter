// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Latvian (`lv`).
class AppLocalizationsLv extends AppLocalizations {
  AppLocalizationsLv([String locale = 'lv']) : super(locale);

  @override
  String get appTitle => 'Globly';

  @override
  String get tagline => 'Dalies ar mirkļiem no visas pasaules';

  @override
  String get languageName => 'Latviešu';

  @override
  String get username => 'Lietotājvārds';

  @override
  String get password => 'Parole';

  @override
  String get signIn => 'Pieslēgties';

  @override
  String get register => 'Reģistrēties';

  @override
  String get createAccount => 'Izveidot kontu';

  @override
  String get browseAsGuest => 'Turpināt bez konta';

  @override
  String get or => 'vai';

  @override
  String get usernameLength => '3–32 rakstzīmes';

  @override
  String get usernameChars => 'Tikai burti, cipari un . _ -';

  @override
  String get passwordLength => 'Vismaz 8 rakstzīmes';

  @override
  String get humanCheckRequired =>
      'Lūdzu, vispirms izpildiet cilvēka pārbaudi.';

  @override
  String get navMap => 'Karte';

  @override
  String get navFeed => 'Plūsma';

  @override
  String get navProfile => 'Profils';

  @override
  String get newPost => 'Jauns ieraksts';

  @override
  String get signInToPost => 'Pieslēdzieties, lai publicētu ierakstus.';

  @override
  String get signInToRate => 'Pieslēdzieties, lai vērtētu ierakstus.';

  @override
  String get filters => 'Filtri';

  @override
  String get contentType => 'Satura veids';

  @override
  String get mediaText => 'Teksts';

  @override
  String get mediaImage => 'Foto';

  @override
  String get mediaVideo => 'Video';

  @override
  String get mediaAudio => 'Audio';

  @override
  String get posted => 'Publicēts';

  @override
  String get anyTime => 'Jebkad';

  @override
  String get last24h => '24 stundās';

  @override
  String get last7d => '7 dienās';

  @override
  String get last30d => '30 dienās';

  @override
  String get positiveOnly => 'Tikai pozitīvi novērtētie';

  @override
  String get reset => 'Atiestatīt';

  @override
  String get apply => 'Lietot';

  @override
  String get newest => 'Jaunākie';

  @override
  String get nearby => 'Tuvumā';

  @override
  String get noPostsYet => 'Šeit vēl nav ierakstu';

  @override
  String get noPostsHint => 'Esi pirmais, kas kaut ko publicē!';

  @override
  String get retry => 'Mēģināt vēlreiz';

  @override
  String get open => 'Atvērt';

  @override
  String get comments => 'Komentāri';

  @override
  String get addComment => 'Pievienot komentāru…';

  @override
  String get noComments => 'Vēl nav komentāru.';

  @override
  String viewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skatījumi: $count',
    );
    return '$_temp0';
  }

  @override
  String get edit => 'Rediģēt';

  @override
  String get delete => 'Dzēst';

  @override
  String get cancel => 'Atcelt';

  @override
  String get save => 'Saglabāt';

  @override
  String get report => 'Ziņot';

  @override
  String get reportTitle => 'Ziņot par šo ierakstu?';

  @override
  String get reportHint =>
      'Ja pietiekami daudz lietotāju ziņo par ierakstu, tas tiek paslēpts līdz moderatora pārbaudei.';

  @override
  String get reportReason => 'Iemesls (nav obligāts)';

  @override
  String get reportThanks => 'Paldies par ziņojumu.';

  @override
  String get reportHidden => 'Paldies. Ieraksts ir paslēpts līdz pārbaudei.';

  @override
  String get editPost => 'Rediģēt ierakstu';

  @override
  String get title => 'Virsraksts';

  @override
  String get descriptionOptional => 'Apraksts (nav obligāts)';

  @override
  String get text => 'Teksts';

  @override
  String get deletePostTitle => 'Dzēst ierakstu?';

  @override
  String get deletePostBody =>
      'Ieraksts un tā faili tiks neatgriezeniski dzēsti.';

  @override
  String get deleteCommentTitle => 'Dzēst komentāru?';

  @override
  String get cannotUndo => 'Šo darbību nevar atsaukt.';

  @override
  String get hidden => 'Paslēpts';

  @override
  String get hiddenReports =>
      'Paslēpts: par šo ierakstu ziņoja vairāki lietotāji. Moderators to pārskatīs.';

  @override
  String get hiddenDownvotes =>
      'Paslēpts: ieraksts saņēma pārsvarā negatīvus vērtējumus. Moderators to pārskatīs.';

  @override
  String get hiddenAdmin => 'Paslēpis moderators.';

  @override
  String get hiddenAutomatic =>
      'Paslēpts: mūsu filtrs atzīmēja šo ierakstu kā, iespējams, nepiedienīgu. Moderators to pārskatīs.';

  @override
  String get publish => 'Publicēt';

  @override
  String get published => 'Ieraksts publicēts.';

  @override
  String uploading(int percent) {
    return 'Augšupielādē… $percent%';
  }

  @override
  String get chooseFileFirst => 'Vispirms izvēlieties failu.';

  @override
  String get titleRequired => 'Virsraksts ir obligāts';

  @override
  String get writeSomething => 'Uzrakstiet kaut ko';

  @override
  String get location => 'Atrašanās vieta';

  @override
  String get retake => 'Uzņemt vēlreiz';

  @override
  String get recording => 'Notiek ieraksts…';

  @override
  String get stopRecording => 'Apturēt';

  @override
  String get microphoneNeeded =>
      'Atļaujiet piekļuvi mikrofonam, lai ierakstītu audio.';

  @override
  String get captureFailed =>
      'Neizdevās sākt ierakstu. Lūdzu, mēģiniet vēlreiz.';

  @override
  String approximateLocation(String distance) {
    return 'Aptuveni $distance rādiusā';
  }

  @override
  String get moreFilters => 'Citi filtri';

  @override
  String get whereCaptured => 'Kur tas tika uzņemts?';

  @override
  String get gettingLocation => 'Nosaka atrašanās vietu…';

  @override
  String get useMyLocation => 'Izmantot manu atrašanās vietu';

  @override
  String get locationRequired => 'Atrašanās vieta ir obligāta.';

  @override
  String get locationServicesOff => 'Atrašanās vietas pakalpojumi ir izslēgti.';

  @override
  String get locationDenied =>
      'Atļauja izmantot atrašanās vietu netika piešķirta.';

  @override
  String get locationDeniedBrowser =>
      'Atrašanās vieta šai vietnei ir bloķēta. Atļauj to pārlūka vietnes iestatījumos (iPhone ierīcē pārbaudi arī Iestatījumi → Konfidencialitāte un drošība → Atrašanās vietas pakalpojumi → Safari vietnes → Lietotnes lietošanas laikā), tad spied “Mēģināt vēlreiz”.';

  @override
  String get locationUnavailable => 'Neizdevās noteikt atrašanās vietu.';

  @override
  String get couldNotLoadVideo => 'Neizdevās ielādēt video';

  @override
  String get guestTitle => 'Jūs pārlūkojat kā viesis';

  @override
  String get guestBody =>
      'Pieslēdzieties, lai publicētu, komentētu un vērtētu.';

  @override
  String get signInOrRegister => 'Pieslēgties vai reģistrēties';

  @override
  String get myPosts => 'Mani ieraksti';

  @override
  String get noMyPosts => 'Jūs vēl neko neesat publicējis.';

  @override
  String get signOut => 'Iziet';

  @override
  String get administration => 'Administrēšana';

  @override
  String get language => 'Valoda';

  @override
  String get systemLanguage => 'Sistēmas valoda';

  @override
  String get posts => 'Ieraksti';

  @override
  String get score => 'Vērtējums';

  @override
  String get admin => 'Administrators';

  @override
  String get hiddenPosts => 'Pārskatīšanai';

  @override
  String get users => 'Lietotāji';

  @override
  String get nothingToReview => 'Nav ko pārskatīt.';

  @override
  String get restore => 'Atjaunot';

  @override
  String get approve => 'Apstiprināt';

  @override
  String get hide => 'Paslēpt';

  @override
  String reasonReports(int count) {
    return 'Ziņojumi: $count';
  }

  @override
  String get reasonDownvotes => 'Pārsvarā negatīvi novērtēts';

  @override
  String get reasonAdmin => 'Paslēpis moderators';

  @override
  String reasonAutomatic(int percent) {
    return 'Automātiski paslēpts: NSFW $percent%';
  }

  @override
  String reasonFlagged(int percent) {
    return 'Atzīmēts: NSFW $percent%';
  }

  @override
  String get searchUsers => 'Meklēt lietotājus';

  @override
  String userPostCount(int count) {
    return 'Ieraksti: $count';
  }

  @override
  String deleteUserTitle(String name) {
    return 'Dzēst lietotāju $name?';
  }

  @override
  String get deleteUserBody =>
      'Lietotāja konts un visi tā ieraksti tiks dzēsti.';

  @override
  String get justNow => 'tikko';

  @override
  String minutesAgo(int n) {
    return 'pirms $n min';
  }

  @override
  String hoursAgo(int n) {
    return 'pirms $n h';
  }

  @override
  String daysAgo(int n) {
    return 'pirms $n d';
  }

  @override
  String get errCannotReach =>
      'Neizdevās sazināties ar serveri. Pārbaudiet savienojumu.';

  @override
  String get errTimeout => 'Serveris pārāk ilgi neatbildēja.';

  @override
  String get errUsernameTaken => 'Šis lietotājvārds jau ir aizņemts.';

  @override
  String get errInvalidCredentials => 'Nepareizs lietotājvārds vai parole.';

  @override
  String get errLockedOut =>
      'Pārāk daudz neveiksmīgu mēģinājumu. Mēģiniet vēlāk.';

  @override
  String get errCaptcha => 'Cilvēka pārbaude neizdevās. Mēģiniet vēlreiz.';

  @override
  String get errContentRejected => 'Šāds saturs nav atļauts.';

  @override
  String get errInvalidFile => 'Šis faila veids netiek atbalstīts.';

  @override
  String get errFileTooLarge => 'Fails ir pārāk liels.';

  @override
  String get errCaptureInvalid =>
      'Neizdevās apstiprināt, ka šis ieraksts uzņemts Globly. Lūdzu, uzņemiet to vēlreiz.';

  @override
  String get errCaptureExpired =>
      'Šis ieraksts ir pārāk vecs, lai to publicētu. Lūdzu, uzņemiet to vēlreiz.';

  @override
  String get errTextRequired => 'Vispirms uzrakstiet tekstu.';

  @override
  String get errCommentEmpty => 'Vispirms uzrakstiet komentāru.';

  @override
  String get errCannotDeleteSelf => 'Šeit nevar dzēst savu kontu.';

  @override
  String get errSignInAgain => 'Lūdzu, pieslēdzieties vēlreiz.';

  @override
  String get errForbidden => 'Jums nav atļauts to darīt.';

  @override
  String get errNotFound => 'Nav atrasts. Iespējams, tas ir dzēsts.';

  @override
  String get errTooMany => 'Pārāk daudz mēģinājumu. Mēģiniet pēc minūtes.';

  @override
  String get errInvalidInput => 'Lūdzu, pārbaudiet ievadītos datus.';

  @override
  String get errGeneric => 'Kaut kas nogāja greizi.';

  @override
  String get checkForUpdates => 'Pārbaudīt atjauninājumus';

  @override
  String appVersion(String version) {
    return 'Versija $version';
  }

  @override
  String get upToDate => 'Jums ir jaunākā versija.';

  @override
  String get updateCheckFailed => 'Neizdevās pārbaudīt atjauninājumus.';

  @override
  String get updateAvailable => 'Pieejams atjauninājums';

  @override
  String updateAvailableBody(String version, String current) {
    return 'Pieejama versija $version. Jums ir $current.';
  }

  @override
  String get updateLater => 'Vēlāk';

  @override
  String get updateNow => 'Atjaunināt';

  @override
  String updateDownloading(int percent) {
    return 'Lejupielādē… $percent%';
  }

  @override
  String get updateFailed => 'Atjauninājumu neizdevās lejupielādēt.';

  @override
  String get feedViewImmersive => 'Pilnekrāna plūsma';

  @override
  String get feedViewList => 'Saraksta plūsma';

  @override
  String get showOnMap => 'Rādīt kartē';

  @override
  String get soundOn => 'Ieslēgt skaņu';

  @override
  String get soundOff => 'Izslēgt skaņu';

  @override
  String get readMore => 'Lasīt vairāk';

  @override
  String get postDetails => 'Ieraksta informācija';
}
