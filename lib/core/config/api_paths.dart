abstract final class ApiPaths {
  static const baseUrl = String.fromEnvironment(
    'GIVECHAIN_BASE_URL',
    defaultValue: 'https://givechain.runasp.net',
  );

  // Auth
  static const login = '/api/mobile/auth/login';
  static const signup = '/api/mobile/auth/register';
  static const forgotPassword = '/api/mobile/auth/forgot-password';
  static const resetPassword = '/api/mobile/auth/reset-password';
  static const infoFields = '/api/mobile/auth/info-fields';

  // Public browse
  static const home = '/api/mobile/home';
  static const charities = '/api/mobile/charities';
  static const campaigns = '/api/mobile/campaigns';
  static const cases = '/api/mobile/cases';

  // Authenticated user resources
  static const donations = '/api/mobile/donations';
  static const centers = '/api/mobile/centers';
  static const benefits = '/api/mobile/benefits';
  static const complaints = '/api/mobile/complaints';
  static const notifications = '/api/mobile/notifications';
  static const profile = '/api/mobile/profile';

  // Shared lookups/media
  static const countries = '/api/lookup/countries';
  static const citiesPath = '/api/lookup/cities';
  static const caseCategories = '/api/lookup/case-categories';
  // Cross-charity benefit-type lookup, backing the "choose a benefit type"
  // step of the Benefits feature. Pass `charityId` to scope it to a single
  // charity; omit it to list every active type across charities.
  //
  // NOTE: as of 2026-08-30 this path answers 404 on the deployed backend, so
  // [BenefitRepository.benefitTypes] falls back to [charityBenefitTypes] —
  // which already serves the identical payload — whenever a charity is known.
  static const benefitTypesLookup = '/api/lookup/benefit-types';
  static const campaignTypes = '/api/lookup/campaign-types';
  static const media = '/api/media';
  static const version = '/api/version';
  static const charityLookup = '/api/charities/lookup';

  static String charityLookupBySubdomain(String subdomain) =>
      '$charityLookup?subdomain=${Uri.encodeQueryComponent(subdomain.trim())}';

  static String campaign(String id) => '$campaigns/${_id(id)}';
  static String caseById(String id) => '$cases/${_id(id)}';
  static String charity(String id) => '$charities/${_id(id)}';
  static String charityCampaigns(String id) =>
      '$charities/${_id(id)}/campaigns';
  static String charityCases(String id) => '$charities/${_id(id)}/cases';
  static String charityBenefitTypes(String id) =>
      '$charities/${_id(id)}/benefit-types';
  static String campaignsByCharity(String id) =>
      '$campaigns/by-charity/${_id(id)}';
  static String casesByCharity(String id) => '$cases/by-charity/${_id(id)}';
  static String campaignDonation(String id) => '$campaigns/${_id(id)}/donate';
  static String caseDonation(String id) => '$cases/${_id(id)}/donate';
  // NOTE: there is deliberately no `confirm-payment` path. The backend has
  // no such endpoint: payment is always settled manually, so a bank transfer
  // is progressed by uploading a receipt via [donationProof] instead.
  static String donationProof(String id) => '$donations/${_id(id)}/proof';
  static String donationDroppedAtCenter(String id) =>
      '$donations/${_id(id)}/dropped-at-center';
  static String donationTrace(String id) => '$donations/${_id(id)}/trace';
  static const donationTraceAll = '$donations/trace';
  static String complaint(String id) => '$complaints/${_id(id)}';
  static const notificationUnreadCount = '$notifications/unread-count';
  static String notificationRead(String id) => '$notifications/${_id(id)}/read';
  static const notificationReadAll = '$notifications/read-all';
  static const profileInfoAnswers = '$profile/info-answers';
  static const profilePassword = '$profile/password';
  static String mediaByOwner({
    required int ownerType,
    required String ownerId,
  }) =>
      '$media?ownerType=$ownerType&ownerId=${Uri.encodeQueryComponent(ownerId)}';
  static String mediaDelete(String id) => '$media/${_id(id)}';
  static String caseCategory(String id) => '$caseCategories/${_id(id)}';
  static String campaignType(String id) => '$campaignTypes/${_id(id)}';

  static String _id(String value) => Uri.encodeComponent(value.trim());
}
