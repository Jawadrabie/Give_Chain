import '../../catalog/data/catalog_models.dart';

class HomeOverview {
  const HomeOverview({
    this.campaigns = const [],
    this.cases = const [],
    this.charities = const [],
  });

  final List<CatalogItem> campaigns;
  final List<CatalogItem> cases;
  final List<Charity> charities;

  bool get isEmpty => campaigns.isEmpty && cases.isEmpty && charities.isEmpty;
}
