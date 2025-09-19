// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Dube App';

  @override
  String get cancel => 'Cancel';

  @override
  String get appName => 'Dube';

  @override
  String get login => 'Login';

  @override
  String get signup => 'Sign Up';

  @override
  String get createAccount => 'Create Account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get name => 'Full name';

  @override
  String get fillAllFields => 'Please fill in all fields.';

  @override
  String get passwordsDontMatch => 'Passwords do not match.';

  @override
  String get loginSuccessful => 'Logged in successfully.';

  @override
  String get signupSuccessful => 'Account created.';

  @override
  String get or => 'or';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get googleSignInPlaceholder => 'Google sign-in not implemented';

  @override
  String get googleSignInCancelled => 'Google sign-in cancelled.';

  @override
  String get googleSignInSuccess => 'Signed in with Google.';

  @override
  String get termsHint => 'By continuing, you agree to the terms.';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get chooseYourLanguage => 'Choose your language';

  @override
  String get changeLaterHint => 'You can change this later in settings.';

  @override
  String get englishLabel => 'English';

  @override
  String get englishSubLabel => 'Use the app in English';

  @override
  String get amharicLabel => 'አማርኛ';

  @override
  String get amharicSubLabel => 'በአማርኛ መጠቀም';

  @override
  String get next => 'Next';

  @override
  String get waitingDirection => 'Loading...';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get backupToCloud => 'Backup to Cloud';

  @override
  String get backupHint => 'Upload a cloud backup so you can restore later';

  @override
  String get backup => 'Backup';

  @override
  String get exportBackup => 'Export backup (share file)';

  @override
  String get exportHint => 'Create a local file you can share or store';

  @override
  String get share => 'Share';

  @override
  String get restoreFromCloud => 'Restore from Cloud';

  @override
  String get restoreHint => 'Restore latest backup from cloud (overwrites local data)';

  @override
  String get restore => 'Restore';

  @override
  String get signOut => 'Sign out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get analytics => 'Analytics';

  @override
  String get analyticsHint => 'Share anonymous usage data to improve the app';

  @override
  String get autoBackup => 'Auto backup';

  @override
  String get language => 'Language';

  @override
  String get languageHint => 'Change app language';

  @override
  String get about => 'About & help';

  @override
  String get aboutHint => 'Help, FAQ and privacy';

  @override
  String get aboutText => 'Dube helps you track who owes what.';

  @override
  String get shareApp => 'Share app';

  @override
  String get guest => 'Guest';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get signIn => 'Sign in';

  @override
  String get privacy => 'Privacy: your data stays on your device unless you upload a backup.';

  @override
  String get paidPerson => 'Paid Person';

  @override
  String get didPersonPay => 'Did this person pay you?';

  @override
  String get yes => 'Yes';

  @override
  String get profile => 'Profile';

  @override
  String get helpFaq => 'Help & FAQ';

  @override
  String appVersion(Object version) {
    return 'App version $version';
  }

  @override
  String get addPersonName => 'Add person name';

  @override
  String get active => 'Active';

  @override
  String get paid => 'Paid';

  @override
  String get searchPeople => 'Search people';

  @override
  String get noPeopleYet => 'No people yet';

  @override
  String get searchPeopleToViewDubes => 'Search people to view dubes';

  @override
  String get whoOwesYou => '👋 Who owes you 💸';

  @override
  String get goToDubes => 'Go to Dubes';

  @override
  String get goToHome => 'Go to Home';

  @override
  String get logout => 'Logout';

  @override
  String get settings => 'Settings';

  @override
  String get enterItemNameAndValidPrice => 'Please enter item name and valid price';

  @override
  String get editDube => 'Edit Dube';

  @override
  String get itemName => 'Item name';

  @override
  String get quantity => 'Quantity';

  @override
  String get pricePerItem => 'Price (per item)';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get save => 'Save';

  @override
  String get markAsPaid => 'Mark as Paid';

  @override
  String get areYouSureMarkAsPaid => 'Are you sure you want to mark this item as paid?';

  @override
  String get addPeopleFromHome => 'Add people from the Home tab or use the Add button there.';

  @override
  String get searchItems => 'Search items...';

  @override
  String get noDubesYet => 'No dubes yet';

  @override
  String get price => 'Price';

  @override
  String get add => 'Add';

  @override
  String get dubes => 'Dubes';

  @override
  String get addNewDube => 'Add new dube';

  @override
  String get enterReferenceNumber => 'Please enter a reference/receipt number';

  @override
  String get noUserSignedIn => 'No user signed in';

  @override
  String get paymentReferenceAlreadyUsed => 'This payment reference appears to be already used';

  @override
  String get errorProcessingPayment => 'Error processing payment:';

  @override
  String get errorSelectingImage => 'Error selecting image:';

  @override
  String get couldNotExtractReference => 'Could not extract reference from image. Please enter it manually.';

  @override
  String get failedToProcessImage => 'Failed to process image. Please try again or enter reference manually.';

  @override
  String get errorProcessingImage => 'Error processing image:';

  @override
  String get invalidVerificationResponse => 'Invalid verification response';

  @override
  String get couldNotVerifyPaymentAmount => 'Could not verify payment amount. Please try again.';

  @override
  String get paymentMustBeAtLeast => 'Payment must be at least';

  @override
  String get found => 'Found';

  @override
  String get paymentVerificationFailed => 'Payment verification failed. Please ensure you sent to the correct recipient.';

  @override
  String get couldNotDetermineTransactionReference => 'Could not determine transaction reference';

  @override
  String get enterValidReferenceNumber => 'Please enter a valid reference number';

  @override
  String get verificationFailed => 'Verification failed';

  @override
  String get errorVerifyingPayment => 'Error verifying payment:';

  @override
  String get referenceNumber => 'Reference Number';

  @override
  String get extractedFromReceipt => 'Extracted from receipt';

  @override
  String get verifyPayment => 'Verify Payment';

  @override
  String get goPremium => 'Go Premium';

  @override
  String get freeAccessEnded => 'Your free access has ended. Unlock unlimited access with a yearly plan.';

  @override
  String get yearly => 'Yearly';

  @override
  String get oneYearFullAccess => '1 year full access';

  @override
  String get unlimitedPeopleAndDubes => 'Unlimited people and dubes';

  @override
  String get cloudBackupAndRestore => 'Cloud backup & restore';

  @override
  String get priorityUpdates => 'Priority updates';

  @override
  String get whyUpgrade => 'Why upgrade?';

  @override
  String get payStepsTitle => 'How to Pay';

  @override
  String get payStep1 => 'Choose one of the following accounts to pay:';

  @override
  String get payStep2 => 'Send the payment using your preferred method.';

  @override
  String get payStep3 => 'Take a screenshot or note the transaction ID.';

  @override
  String get payStep4 => 'Back to this app and paste the transaction ID or upload the screenshot.';

  @override
  String get payStep5 => 'Click Verify Payment.';

  @override
  String get keepHistorySafe => 'Keep your history safe with cloud backups';

  @override
  String get trackWithoutLimits => 'Track without limits all year long';

  @override
  String get supportOngoingDevelopment => 'Support ongoing development';

  @override
  String get howToPayTitle => 'How to Pay (Step by Step)';

  @override
  String get howToPayStep1 => 'Pay using one of the options below.';

  @override
  String get howToPayStep2 => 'After payment, copy the Transaction ID or Reference Number.';

  @override
  String get howToPayStep3 => 'Return here and enter the ID to unlock premium.';

  @override
  String get telebirrInstruction => 'Telebirr (send to this number)';

  @override
  String get telebirrNumber => '251900647953';

  @override
  String get bankInstruction => 'Commercial Bank of Ethiopia (digital transfer)';

  @override
  String get bankAccount => '1000711023015';

  @override
  String get choosePaymentMethod => 'Choose payment method';

  @override
  String get telebirr => 'Telebirr';

  @override
  String get cbeRefSuffix => 'CBE (reference + suffix)';

  @override
  String get abyssiniaRefSuffix => 'Abyssinia (reference + suffix)';

  @override
  String get cbeBirrReceiptPhone => 'CBE Birr (receipt + phone)';

  @override
  String get uploadReceiptImage => 'Upload receipt image';

  @override
  String get accountSuffix => 'Account suffix';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get extractedReference => 'Extracted reference';

  @override
  String get needHelpContactSupport => 'Need help? Contact support@example.com';

  @override
  String get helpContactDetail => 'If you have any questions, issues, or feedback, please reach out to us using the contact information below.';
  @override
  String get emailSupport => 'Email';
  @override
  String get supportEmail => 'support@dubeapp.example';
  @override
  String get faqHeader => 'FAQ';
  @override
  String get faqAddPerson => '• How do I add a person? Use the Home screen add field.';
  @override
  String get faqViewDubes => '• How do I view dubes? Tap a person to open their dubes.';
  @override
  String get faqEditDeleteDube => '• How do I edit/delete a dube? Use the menu on each item.';
}
