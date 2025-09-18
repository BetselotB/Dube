import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Dube App'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Dube'**
  String get appName;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get name;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields.'**
  String get fillAllFields;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDontMatch;

  /// No description provided for @loginSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Logged in successfully.'**
  String get loginSuccessful;

  /// No description provided for @signupSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Account created.'**
  String get signupSuccessful;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @googleSignInPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in not implemented'**
  String get googleSignInPlaceholder;

  /// No description provided for @googleSignInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in cancelled.'**
  String get googleSignInCancelled;

  /// No description provided for @googleSignInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed in with Google.'**
  String get googleSignInSuccess;

  /// No description provided for @termsHint.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to the terms.'**
  String get termsHint;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @chooseYourLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseYourLanguage;

  /// No description provided for @changeLaterHint.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in settings.'**
  String get changeLaterHint;

  /// No description provided for @englishLabel.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLabel;

  /// No description provided for @englishSubLabel.
  ///
  /// In en, this message translates to:
  /// **'Use the app in English'**
  String get englishSubLabel;

  /// No description provided for @amharicLabel.
  ///
  /// In en, this message translates to:
  /// **'አማርኛ'**
  String get amharicLabel;

  /// No description provided for @amharicSubLabel.
  ///
  /// In en, this message translates to:
  /// **'በአማርኛ መጠቀም'**
  String get amharicSubLabel;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @waitingDirection.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get waitingDirection;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @backupToCloud.
  ///
  /// In en, this message translates to:
  /// **'Backup to Cloud'**
  String get backupToCloud;

  /// No description provided for @backupHint.
  ///
  /// In en, this message translates to:
  /// **'Upload a cloud backup so you can restore later'**
  String get backupHint;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup (share file)'**
  String get exportBackup;

  /// No description provided for @exportHint.
  ///
  /// In en, this message translates to:
  /// **'Create a local file you can share or store'**
  String get exportHint;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @restoreFromCloud.
  ///
  /// In en, this message translates to:
  /// **'Restore from Cloud'**
  String get restoreFromCloud;

  /// No description provided for @restoreHint.
  ///
  /// In en, this message translates to:
  /// **'Restore latest backup from cloud (overwrites local data)'**
  String get restoreHint;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @analyticsHint.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous usage data to improve the app'**
  String get analyticsHint;

  /// No description provided for @autoBackup.
  ///
  /// In en, this message translates to:
  /// **'Auto backup'**
  String get autoBackup;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageHint.
  ///
  /// In en, this message translates to:
  /// **'Change app language'**
  String get languageHint;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About & help'**
  String get about;

  /// No description provided for @aboutHint.
  ///
  /// In en, this message translates to:
  /// **'Help, FAQ and privacy'**
  String get aboutHint;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'Dube helps you track who owes what.'**
  String get aboutText;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share app'**
  String get shareApp;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy: your data stays on your device unless you upload a backup.'**
  String get privacy;

  /// No description provided for @paidPerson.
  ///
  /// In en, this message translates to:
  /// **'Paid Person'**
  String get paidPerson;

  /// No description provided for @didPersonPay.
  ///
  /// In en, this message translates to:
  /// **'Did this person pay you?'**
  String get didPersonPay;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @helpFaq.
  ///
  /// In en, this message translates to:
  /// **'Help & FAQ'**
  String get helpFaq;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version {version}'**
  String appVersion(Object version);

  /// No description provided for @addPersonName.
  ///
  /// In en, this message translates to:
  /// **'Add person name'**
  String get addPersonName;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @searchPeople.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get searchPeople;

  /// No description provided for @noPeopleYet.
  ///
  /// In en, this message translates to:
  /// **'No people yet'**
  String get noPeopleYet;

  /// No description provided for @searchPeopleToViewDubes.
  ///
  /// In en, this message translates to:
  /// **'Search people to view dubes'**
  String get searchPeopleToViewDubes;

  /// No description provided for @whoOwesYou.
  ///
  /// In en, this message translates to:
  /// **'👋 Who owes you 💸'**
  String get whoOwesYou;

  /// No description provided for @goToDubes.
  ///
  /// In en, this message translates to:
  /// **'Go to Dubes'**
  String get goToDubes;

  /// No description provided for @goToHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get goToHome;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @enterItemNameAndValidPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter item name and valid price'**
  String get enterItemNameAndValidPrice;

  /// No description provided for @editDube.
  ///
  /// In en, this message translates to:
  /// **'Edit Dube'**
  String get editDube;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get itemName;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @pricePerItem.
  ///
  /// In en, this message translates to:
  /// **'Price (per item)'**
  String get pricePerItem;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @markAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as Paid'**
  String get markAsPaid;

  /// No description provided for @areYouSureMarkAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to mark this item as paid?'**
  String get areYouSureMarkAsPaid;

  /// No description provided for @addPeopleFromHome.
  ///
  /// In en, this message translates to:
  /// **'Add people from the Home tab or use the Add button there.'**
  String get addPeopleFromHome;

  /// No description provided for @searchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items...'**
  String get searchItems;

  /// No description provided for @noDubesYet.
  ///
  /// In en, this message translates to:
  /// **'No dubes yet'**
  String get noDubesYet;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @dubes.
  ///
  /// In en, this message translates to:
  /// **'Dubes'**
  String get dubes;

  /// No description provided for @addNewDube.
  ///
  /// In en, this message translates to:
  /// **'Add new dube'**
  String get addNewDube;

  /// No description provided for @enterReferenceNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a reference/receipt number'**
  String get enterReferenceNumber;

  /// No description provided for @noUserSignedIn.
  ///
  /// In en, this message translates to:
  /// **'No user signed in'**
  String get noUserSignedIn;

  /// No description provided for @paymentReferenceAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This payment reference appears to be already used'**
  String get paymentReferenceAlreadyUsed;

  /// No description provided for @errorProcessingPayment.
  ///
  /// In en, this message translates to:
  /// **'Error processing payment:'**
  String get errorProcessingPayment;

  /// No description provided for @errorSelectingImage.
  ///
  /// In en, this message translates to:
  /// **'Error selecting image:'**
  String get errorSelectingImage;

  /// No description provided for @couldNotExtractReference.
  ///
  /// In en, this message translates to:
  /// **'Could not extract reference from image. Please enter it manually.'**
  String get couldNotExtractReference;

  /// No description provided for @failedToProcessImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to process image. Please try again or enter reference manually.'**
  String get failedToProcessImage;

  /// No description provided for @errorProcessingImage.
  ///
  /// In en, this message translates to:
  /// **'Error processing image:'**
  String get errorProcessingImage;

  /// No description provided for @invalidVerificationResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid verification response'**
  String get invalidVerificationResponse;

  /// No description provided for @couldNotVerifyPaymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Could not verify payment amount. Please try again.'**
  String get couldNotVerifyPaymentAmount;

  /// No description provided for @paymentMustBeAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Payment must be at least'**
  String get paymentMustBeAtLeast;

  /// No description provided for @found.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get found;

  /// No description provided for @paymentVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment verification failed. Please ensure you sent to the correct recipient.'**
  String get paymentVerificationFailed;

  /// No description provided for @couldNotDetermineTransactionReference.
  ///
  /// In en, this message translates to:
  /// **'Could not determine transaction reference'**
  String get couldNotDetermineTransactionReference;

  /// No description provided for @enterValidReferenceNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid reference number'**
  String get enterValidReferenceNumber;

  /// No description provided for @verificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get verificationFailed;

  /// No description provided for @errorVerifyingPayment.
  ///
  /// In en, this message translates to:
  /// **'Error verifying payment:'**
  String get errorVerifyingPayment;

  /// No description provided for @referenceNumber.
  ///
  /// In en, this message translates to:
  /// **'Reference Number'**
  String get referenceNumber;

  /// No description provided for @extractedFromReceipt.
  ///
  /// In en, this message translates to:
  /// **'Extracted from receipt'**
  String get extractedFromReceipt;

  /// No description provided for @verifyPayment.
  ///
  /// In en, this message translates to:
  /// **'Verify Payment'**
  String get verifyPayment;

  /// No description provided for @goPremium.
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get goPremium;

  /// No description provided for @freeAccessEnded.
  ///
  /// In en, this message translates to:
  /// **'Your free access has ended. Unlock unlimited access with a yearly plan.'**
  String get freeAccessEnded;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @oneYearFullAccess.
  ///
  /// In en, this message translates to:
  /// **'1 year full access'**
  String get oneYearFullAccess;

  /// No description provided for @unlimitedPeopleAndDubes.
  ///
  /// In en, this message translates to:
  /// **'Unlimited people and dubes'**
  String get unlimitedPeopleAndDubes;

  /// No description provided for @cloudBackupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup & restore'**
  String get cloudBackupAndRestore;

  /// No description provided for @priorityUpdates.
  ///
  /// In en, this message translates to:
  /// **'Priority updates'**
  String get priorityUpdates;

  /// No description provided for @whyUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Why upgrade?'**
  String get whyUpgrade;

  /// No description provided for @payStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'How to Pay'**
  String get payStepsTitle;

  /// No description provided for @payStep1.
  ///
  /// In en, this message translates to:
  /// **'Choose one of the following accounts to pay:'**
  String get payStep1;

  /// No description provided for @payStep2.
  ///
  /// In en, this message translates to:
  /// **'Send the payment using your preferred method.'**
  String get payStep2;

  /// No description provided for @payStep3.
  ///
  /// In en, this message translates to:
  /// **'Take a screenshot or note the transaction ID.'**
  String get payStep3;

  /// No description provided for @payStep4.
  ///
  /// In en, this message translates to:
  /// **'Back to this app and paste the transaction ID or upload the screenshot.'**
  String get payStep4;

  /// No description provided for @payStep5.
  ///
  /// In en, this message translates to:
  /// **'Click Verify Payment.'**
  String get payStep5;

  /// No description provided for @keepHistorySafe.
  ///
  /// In en, this message translates to:
  /// **'Keep your history safe with cloud backups'**
  String get keepHistorySafe;

  /// No description provided for @trackWithoutLimits.
  ///
  /// In en, this message translates to:
  /// **'Track without limits all year long'**
  String get trackWithoutLimits;

  /// No description provided for @supportOngoingDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Support ongoing development'**
  String get supportOngoingDevelopment;

  /// No description provided for @howToPayTitle.
  ///
  /// In en, this message translates to:
  /// **'How to Pay (Step by Step)'**
  String get howToPayTitle;

  /// No description provided for @howToPayStep1.
  ///
  /// In en, this message translates to:
  /// **'Pay using one of the options below.'**
  String get howToPayStep1;

  /// No description provided for @howToPayStep2.
  ///
  /// In en, this message translates to:
  /// **'After payment, copy the Transaction ID or Reference Number.'**
  String get howToPayStep2;

  /// No description provided for @howToPayStep3.
  ///
  /// In en, this message translates to:
  /// **'Return here and enter the ID to unlock premium.'**
  String get howToPayStep3;

  /// No description provided for @telebirrInstruction.
  ///
  /// In en, this message translates to:
  /// **'Telebirr (send to this number)'**
  String get telebirrInstruction;

  /// No description provided for @telebirrNumber.
  ///
  /// In en, this message translates to:
  /// **'251900647953'**
  String get telebirrNumber;

  /// No description provided for @bankInstruction.
  ///
  /// In en, this message translates to:
  /// **'Commercial Bank of Ethiopia (digital transfer)'**
  String get bankInstruction;

  /// No description provided for @bankAccount.
  ///
  /// In en, this message translates to:
  /// **'1000711023015'**
  String get bankAccount;

  /// No description provided for @choosePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose payment method'**
  String get choosePaymentMethod;

  /// No description provided for @telebirr.
  ///
  /// In en, this message translates to:
  /// **'Telebirr'**
  String get telebirr;

  /// No description provided for @cbeRefSuffix.
  ///
  /// In en, this message translates to:
  /// **'CBE (reference + suffix)'**
  String get cbeRefSuffix;

  /// No description provided for @abyssiniaRefSuffix.
  ///
  /// In en, this message translates to:
  /// **'Abyssinia (reference + suffix)'**
  String get abyssiniaRefSuffix;

  /// No description provided for @cbeBirrReceiptPhone.
  ///
  /// In en, this message translates to:
  /// **'CBE Birr (receipt + phone)'**
  String get cbeBirrReceiptPhone;

  /// No description provided for @uploadReceiptImage.
  ///
  /// In en, this message translates to:
  /// **'Upload receipt image'**
  String get uploadReceiptImage;

  /// No description provided for @accountSuffix.
  ///
  /// In en, this message translates to:
  /// **'Account suffix'**
  String get accountSuffix;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @extractedReference.
  ///
  /// In en, this message translates to:
  /// **'Extracted reference'**
  String get extractedReference;

  /// No description provided for @needHelpContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Need help? Contact support@example.com'**
  String get needHelpContactSupport;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am': return AppLocalizationsAm();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
