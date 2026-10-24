import '../../../models/conversation.dart';

/// Messages rapides proposés au-dessus du champ de saisie, selon l'interlocuteur.
const Map<ConversationType, List<String>> quickRepliesByType = {
  ConversationType.restaurant: [
    'Où en est ma commande ?',
    'Pouvez-vous ajouter des couverts ?',
    'Merci beaucoup !',
  ],
  ConversationType.courier: [
    'Je descends 🏃',
    'Laissez devant la porte',
    'Le digicode est 4521B',
    'Merci !',
  ],
  ConversationType.support: [
    'Problème avec ma commande',
    "Je n'ai pas reçu mon remboursement",
    'Modifier mon adresse',
  ],
};
