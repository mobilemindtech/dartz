class Validation {
  var messages = <String>[];

  Validation();

  factory Validation.init() => Validation();

  String get firstMessage => messages.first;

  Validation notEmpty(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      this.messages.add(message);
    }
    return this;
  }

  Validation notNull(dynamic value, String message) {
    if (value == null) {
      this.messages.add(message);
    }
    return this;
  }

  Validation gt(int value, int min, String message) {
    if (value <= min) {
      this.messages.add(message);
    }
    return this;
  }

  Validation eq(int value, int expected, String message) {
    if (value == expected) {
      this.messages.add(message);
    }
    return this;
  }

  bool get valid => this.messages.isEmpty;

  bool get invalid => !valid;
}
