/// Estado civil (MaritalStatus da API).
enum MaritalStatus {
  single('SINGLE', 'Solteiro(a)'),
  married('MARRIED', 'Casado(a)'),
  widowed('WIDOWED', 'Viúvo(a)'),
  divorced('DIVORCED', 'Divorciado(a)'),
  other('OTHER', 'Outro');

  const MaritalStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Dados de cadastro de um pastor (`POST /pastors`).
///
/// Só `firstName`, `lastName` e `countryId` são obrigatórios na API; o resto
/// vai apenas quando preenchido, para não gravar string vazia no banco.
class NewPastor {
  const NewPastor({
    required this.firstName,
    required this.lastName,
    required this.countryId,
    this.pastoralName,
    this.email,
    this.phone,
    this.whatsapp,
    this.birthDate,
    this.maritalStatus,
    this.spouseName,
    this.regionId,
    this.city,
    this.churchId,
    this.ministryRoleId,
    this.ministryTitle,
    this.joinedAt,
    this.ordainedAt,
    this.supervisorId,
    this.createUserAccount = false,
  });

  final String firstName;
  final String lastName;
  final String countryId;
  final String? pastoralName;
  final String? email;
  final String? phone;
  final String? whatsapp;
  final DateTime? birthDate;
  final MaritalStatus? maritalStatus;
  final String? spouseName;
  final String? regionId;
  final String? city;
  final String? churchId;
  final String? ministryRoleId;
  final String? ministryTitle;
  final DateTime? joinedAt;
  final DateTime? ordainedAt;
  final String? supervisorId;

  /// Cria o usuário de acesso e dispara o convite (a API gera a senha).
  final bool createUserAccount;

  static String? _text(String? value) {
    final clean = value?.trim();
    return (clean == null || clean.isEmpty) ? null : clean;
  }

  /// Datas vão como `yyyy-MM-dd`: a API espera apenas o dia, sem hora.
  static String? _day(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'countryId': countryId,
      'pastoralName': _text(pastoralName),
      'email': _text(email),
      'phone': _text(phone),
      'whatsapp': _text(whatsapp),
      'birthDate': _day(birthDate),
      'maritalStatus': maritalStatus?.apiValue,
      'spouseName': _text(spouseName),
      'regionId': regionId,
      'city': _text(city),
      'churchId': churchId,
      'ministryRoleId': ministryRoleId,
      'ministryTitle': _text(ministryTitle),
      'joinedAt': _day(joinedAt),
      'ordainedAt': _day(ordainedAt),
      'supervisorId': supervisorId,
      if (createUserAccount) 'createUserAccount': true,
    };
    body.removeWhere((_, value) => value == null);
    return body;
  }
}

/// Opção simples para os seletores do formulário.
class SelectOption {
  const SelectOption({required this.id, required this.label, this.detail});

  final String id;
  final String label;
  final String? detail;
}
