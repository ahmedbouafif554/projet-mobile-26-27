/// Contrat commun à tous les dépôts : lister, lire, créer, modifier,
/// supprimer. Chaque entité a une interface qui l'étend, une version mock
/// (données en mémoire) et une version API (Dio).
abstract interface class CrudRepository<T> {
  Future<List<T>> getAll();

  /// Lève une [ApiException] 404 si l'élément n'existe pas.
  Future<T> getById(String id);

  /// Un identifiant vide est attribué par le dépôt.
  Future<T> create(T item);

  Future<T> update(T item);

  Future<void> delete(String id);
}
