class Company {
  final int? id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String sector;
  final String siret;
  final int headcount;
  final String? website;
  final String? logoUrl;
  final String? insurerAtMp; // Assureur AT/MP
  final String? insurerHorsAtMp; // Assureur spécialisé hors AT/MP
  final String? otherSocialContributions; // Autres cotisations sociales
  final String? additionalDetails; // Détails supplémentaires

  Company({
    this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.sector,
    required this.siret,
    required this.headcount,
    this.website,
    this.logoUrl,
    this.insurerAtMp,
    this.insurerHorsAtMp,
    this.otherSocialContributions,
    this.additionalDetails,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      name: json['name'] ?? 'N/A',
      address: json['address'] ?? 'N/A',
      phone: json['phone'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      sector: json['sector'] ?? 'N/A',
      siret: json['siret'] ?? 'N/A',
      headcount: json['headcount'] ?? 0,
      website: json['website'],
      logoUrl: json['logoUrl'],
      insurerAtMp: json['insurerAtMp'],
      insurerHorsAtMp: json['insurerHorsAtMp'],
      otherSocialContributions: json['otherSocialContributions'],
      additionalDetails: json['additionalDetails'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'sector': sector,
      'siret': siret,
      'headcount': headcount,
      'website': website,
      'logoUrl': logoUrl,
      'insurerAtMp': insurerAtMp,
      'insurerHorsAtMp': insurerHorsAtMp,
      'otherSocialContributions': otherSocialContributions,
      'additionalDetails': additionalDetails,
    };
  }
}
