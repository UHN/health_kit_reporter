import 'deleted_object.dart';
import 'sample.dart';

/// Result class for one-shot anchored object queries.
///
/// Contains samples added/modified since the provided anchor,
/// objects deleted since the anchor, and a new anchor for
/// subsequent queries.
class AnchoredQueryResult {
  const AnchoredQueryResult({
    required this.samples,
    required this.deletedObjects,
    this.newAnchor,
  });

  /// Samples added or modified since the previous anchor
  final List<Sample> samples;

  /// Objects deleted since the previous anchor
  final List<DeletedObject> deletedObjects;

  /// New anchor for subsequent queries. Store this value
  /// and pass it to the next queryAnchor call to get only
  /// changes since this point.
  final String? newAnchor;

  /// General map representation
  Map<String, dynamic> get map => {
        'samples': samples.map((s) => s.map).toList(),
        'deletedObjects': deletedObjects.map((d) => d.map).toList(),
        'newAnchor': newAnchor,
      };
}
