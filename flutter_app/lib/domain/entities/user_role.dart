/// User roles supported by Trans-Hub.
enum UserRole { customer, company }

/// Parses a [UserRole] from its string form, defaulting to [UserRole.customer].
UserRole roleFromString(String s) =>
    s == 'company' ? UserRole.company : UserRole.customer;

/// Serializes a [UserRole] to its string form.
String roleToString(UserRole r) =>
    r == UserRole.company ? 'company' : 'customer';
