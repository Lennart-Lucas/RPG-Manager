import 'feat_model.dart';

enum FeatRequirementFilter {
  any('Any'),
  withRequirement('With requirement'),
  withoutRequirement('No requirement');

  const FeatRequirementFilter(this.label);

  final String label;
}

class FeatsListFilter {
  const FeatsListFilter({
    this.hasRequirement = FeatRequirementFilter.any,
  });

  final FeatRequirementFilter hasRequirement;

  static const FeatsListFilter empty = FeatsListFilter();

  bool get hasAny => hasRequirement != FeatRequirementFilter.any;

  FeatsListFilter copyWith({
    FeatRequirementFilter? hasRequirement,
  }) {
    return FeatsListFilter(
      hasRequirement: hasRequirement ?? this.hasRequirement,
    );
  }

  bool matchesFeat(FeatRecord feat) {
    final hasReq = feat.requirement.trim().isNotEmpty;
    return switch (hasRequirement) {
      FeatRequirementFilter.any => true,
      FeatRequirementFilter.withRequirement => hasReq,
      FeatRequirementFilter.withoutRequirement => !hasReq,
    };
  }
}

String featListFilterSignature(FeatsListFilter filter) {
  return filter.hasRequirement.name;
}
