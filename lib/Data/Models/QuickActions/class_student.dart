class ClassStudent {
  final String id;
  final String name;
  final String rollNumber;
  final String email;
  final String? phone;
  final String? department;
  final String? section;
  final String? courseCode;
  final String? courseName;
  final String? semester;
  final String? image;
  final double attendancePercentage;
  final int totalClasses;
  final int attendedClasses;
  final bool isEligible;
  final bool isDefaulter;
  final String? gender;
  final DateTime? lastSeen;
  final String? guardianName;
  final String? guardianPhone;
  final String? address;
  final String? bloodGroup;
  final String? notes;

  ClassStudent({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.email,
    this.phone,
    this.department,
    this.section,
    this.courseCode,
    this.courseName,
    this.semester,
    this.image,
    this.attendancePercentage = 0.0,
    this.totalClasses = 0,
    this.attendedClasses = 0,
    this.isEligible = true,
    this.isDefaulter = false,
    this.gender,
    this.lastSeen,
    this.guardianName,
    this.guardianPhone,
    this.address,
    this.bloodGroup,
    this.notes,
  });

  factory ClassStudent.fromJson(Map<String, dynamic> json) {
    return ClassStudent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      rollNumber: json['roll_number']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      department: json['department']?.toString(),
      section: json['section']?.toString(),
      courseCode: json['course_code']?.toString(),
      courseName: json['course_name']?.toString(),
      semester: json['semester']?.toString(),
      image: json['image']?.toString(),
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      totalClasses: json['total_classes'] as int? ?? 0,
      attendedClasses: json['attended_classes'] as int? ?? 0,
      isEligible: json['is_eligible'] == true,
      isDefaulter: json['is_defaulter'] == true,
      gender: json['gender']?.toString(),
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'].toString())
          : null,
      guardianName: json['guardian_name']?.toString(),
      guardianPhone: json['guardian_phone']?.toString(),
      address: json['address']?.toString(),
      bloodGroup: json['blood_group']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roll_number': rollNumber,
      'email': email,
      if (phone != null) 'phone': phone,
      if (department != null) 'department': department,
      if (section != null) 'section': section,
      if (courseCode != null) 'course_code': courseCode,
      if (courseName != null) 'course_name': courseName,
      if (semester != null) 'semester': semester,
      if (image != null) 'image': image,
      'attendance_percentage': attendancePercentage,
      'total_classes': totalClasses,
      'attended_classes': attendedClasses,
      'is_eligible': isEligible,
      'is_defaulter': isDefaulter,
      if (gender != null) 'gender': gender,
      if (lastSeen != null) 'last_seen': lastSeen!.toIso8601String(),
      if (guardianName != null) 'guardian_name': guardianName,
      if (guardianPhone != null) 'guardian_phone': guardianPhone,
      if (address != null) 'address': address,
      if (bloodGroup != null) 'blood_group': bloodGroup,
      if (notes != null) 'notes': notes,
    };
  }

  ClassStudent copyWith({
    String? id,
    String? name,
    String? rollNumber,
    String? email,
    String? phone,
    String? department,
    String? section,
    String? courseCode,
    String? courseName,
    String? semester,
    String? image,
    double? attendancePercentage,
    int? totalClasses,
    int? attendedClasses,
    bool? isEligible,
    bool? isDefaulter,
    String? gender,
    DateTime? lastSeen,
    String? guardianName,
    String? guardianPhone,
    String? address,
    String? bloodGroup,
    String? notes,
  }) {
    return ClassStudent(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNumber: rollNumber ?? this.rollNumber,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      section: section ?? this.section,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      semester: semester ?? this.semester,
      image: image ?? this.image,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
      totalClasses: totalClasses ?? this.totalClasses,
      attendedClasses: attendedClasses ?? this.attendedClasses,
      isEligible: isEligible ?? this.isEligible,
      isDefaulter: isDefaulter ?? this.isDefaulter,
      gender: gender ?? this.gender,
      lastSeen: lastSeen ?? this.lastSeen,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      address: address ?? this.address,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      notes: notes ?? this.notes,
    );
  }
}
