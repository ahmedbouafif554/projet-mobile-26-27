/// Validateurs de formulaires réutilisables (messages en français).
class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? required(String? value, {String field = 'Ce champ'}) =>
      (value == null || value.trim().isEmpty) ? '$field est obligatoire' : null;

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "L'e-mail est obligatoire";
    }
    if (!_emailRegex.hasMatch(value.trim())) return 'Adresse e-mail invalide';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est obligatoire';
    }
    if (value.length < 6) return 'Au moins 6 caractères';
    return null;
  }

  static String? phone(String? value) {
    final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (digits.isEmpty) return 'Le numéro est obligatoire';
    if (digits.length < 9) return 'Numéro de téléphone invalide';
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Le nom est obligatoire';
    if (value.trim().length < 2) return 'Nom trop court';
    return null;
  }
}
