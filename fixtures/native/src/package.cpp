#include "NativePackageAPI.hpp"

#include <cstddef>

namespace {

bool fixtureGreeting(const ExprHostApi *, const ExprPackageValue *args,
                     size_t argc, ExprPackageValue *result,
                     ExprPackageStringView *error) {
  if (argc != 0 || result == nullptr || args != nullptr) {
    if (error != nullptr) {
      static constexpr char message[] = "fixtureGreeting expects no arguments";
      *error = {message, sizeof(message) - 1};
    }
    return false;
  }
  static constexpr char message[] = "native workflow fixture";
  result->kind = EXPR_PACKAGE_VALUE_STR;
  result->as.string_value = {message, sizeof(message) - 1};
  return true;
}

constexpr ExprPackageFunctionExport functions[] = {
    {"fixtureGreeting", "fn() -> str", 0, fixtureGreeting},
};

constexpr ExprPackageRegistration registration = {
    EXPR_NATIVE_PACKAGE_ABI_VERSION,
    "github",
    "package-actions-native-fixture",
    functions,
    sizeof(functions) / sizeof(functions[0]),
    nullptr,
    0,
};

} // namespace

extern "C" const ExprPackageRegistration *exprRegisterPackage(void) {
  return &registration;
}
