/// Photos de démonstration (Unsplash, chargées depuis Internet).
/// Unsplash autorise le chargement depuis le web (CORS), contrairement à
/// beaucoup de générateurs d'avatars : les photos s'affichent aussi dans le
/// back office.
library;

/// Photo Unsplash à partir de son identifiant.
String unsplash(String id, {int width = 800}) =>
    'https://images.unsplash.com/photo-$id?auto=format&fit=crop&w=$width&q=80';

const _women = [
  '1494790108377-be9c29b29330',
  '1544005313-94ddf0286df2',
  '1438761681033-6461ffad8d80',
  '1534528741775-53994a69daeb',
  '1517841905240-472988babdf9',
  '1580489944761-15a19d654956',
  '1524504388940-b1c1722653e1',
  '1487412720507-e7ab37603c6f',
  '1573496359142-b8d87734a5a2',
];

const _men = [
  '1507003211169-0a1dd7228f2d',
  '1506794778202-cad84cf45f1d',
  '1527980965255-d3b416303d12',
  '1535713875002-d1d0cf377fde',
  '1472099645785-5658abf4ff4e',
  '1539571696357-5a69c17a67c6',
  '1531427186611-ecfd6d936c79',
  '1552058544-f2b08422138a',
  '1463453091185-61582044d556',
  '1599566150163-29194dcaad36',
];

/// Portrait de démonstration (le n-ième de la liste, en boucle).
String portrait({required bool woman, required int index}) {
  final photos = woman ? _women : _men;
  return unsplash(photos[index % photos.length], width: 200);
}
