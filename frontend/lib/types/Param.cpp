/*
 * Copyright 2021-2024 Hewlett Packard Enterprise Development LP
 * Other additional copyright holders may be indicated within.
 *
 * The entirety of this work is licensed under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 *
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "chpl/types/Param.h"

#include "chpl/framework/query-impl.h"
#include "chpl/framework/UniqueString-detail.h"
#include "chpl/types/BoolType.h"
#include "chpl/types/CStringType.h"
#include "chpl/types/ComplexType.h"
#include "chpl/types/ImagType.h"
#include "chpl/types/IntType.h"
#include "chpl/types/RealType.h"
#include "chpl/types/RecordType.h"
#include "chpl/types/UintType.h"

#include "../immediates/num.h"
#include "../immediates/prim_data.h"

#include <cfloat>
#include <cinttypes>
#include <cmath>

namespace chpl {
namespace types {


using namespace uast;

Param::~Param() {
}

bool Param::completeMatch(const Param* other) const {
  const Param* lhs = this;
  const Param* rhs = other;
  if (lhs->tag() != rhs->tag())
    return false;
  if (!lhs->contentsMatchInner(rhs))
    return false;

  return true;
}

bool Param::isParamOpFoldable(chpl::uast::PrimitiveTag op) {
  switch (op) {
    case P_prim_pow:
    case P_prim_mult:
    case P_prim_div:
    case P_prim_mod:
    case P_prim_add:
    case P_prim_subtract:
    case P_prim_lsh:
    case P_prim_rsh:
    case P_prim_less:
    case P_prim_lessorequal:
    case P_prim_greater:
    case P_prim_greaterorequal:
    case P_prim_equal:
    case P_prim_notequal:
    case P_prim_and:
    case P_prim_xor:
    case P_prim_or:
    case P_prim_land:
    case P_prim_lor:
    case P_prim_plus:
    case P_prim_minus:
    case P_prim_not:
    case P_prim_lnot:
    case P_prim_abs:
    case P_prim_sqrt:
      return true;
    default:
      return false;
  }
}


/*
These helpers get the immediate value from a Param in the proper type if the
param exists. Otherwise, they return an empty value of the proper type.
*/
template<typename T, typename S>
static T getImmediateValueOrEmpty(const S* p) {
  if (p) {
    return p->value();
  }
  // handle complex and string types in overloads below
  return (T) 0;
}

static Param::ComplexDouble getImmediateValueOrEmpty(const ComplexParam* p) {
  if (p) {
    return p->value();
  }
  return Param::ComplexDouble(0.0, 0.0);
}

static ImmString getImmediateValueOrEmpty(const StringParam* p) {
  if (p) {
    return p->value().podUniqueString();
  }
  return UniqueString().podUniqueString();
}

static paramtags::ParamTag guessParamTagFromType(const Type* t) {
  if (t->isBoolType()) {
    return paramtags::BoolParam;
  } else if (t->isComplexType()) {
    return paramtags::ComplexParam;
  } else if (t->isIntType()) {
    return paramtags::IntParam;
  } else if (t->isUintType()) {
    return paramtags::UintParam;
  } else if (t->isRealType()) {
    return paramtags::RealParam;
  } else if (t->isImagType()) {
    return paramtags::RealParam;
  } else if (t->isStringType()) {
    return paramtags::StringParam;
  } else if (t->isBytesType()) {
    return paramtags::StringParam;
  } else if (t->isCStringType()) {
    return paramtags::StringParam;
  } else if (t->isNothingType()) {
    return paramtags::NoneParam;
  } else {
    CHPL_ASSERT(false && "case not handled");
  }
  return paramtags::NoneParam;
}

/*
  Get the immediate value from a Param in the proper type. Pass nullptr as param
  to get an empty immediate for a param of Type t.
*/
static
Immediate paramToImmediate(const Param* p, const Type* t) {
  Immediate ret;
  paramtags::ParamTag tag = p ? p->tag() : guessParamTagFromType(t);

  switch (tag) {
    case paramtags::BoolParam:
      {
        auto bp = (const BoolParam*) p;
        auto v = getImmediateValueOrEmpty<bool, BoolParam>(bp);
        ret.const_kind = NUM_KIND_BOOL;
        ret.num_index = BOOL_SIZE_SYS;
        ret.v_bool = v;
        return ret;
      }
    case paramtags::ComplexParam:
      {
        auto cp = (const ComplexParam*) p;
        auto v = getImmediateValueOrEmpty(cp);
        auto ct = t->toComplexType();
        CHPL_ASSERT(ct);
        if (ct == nullptr) return ret;
        ret.const_kind = NUM_KIND_COMPLEX;
        if (ct->bitwidth() == 64) {
          ret.num_index = COMPLEX_SIZE_64;
          ret.v_complex64.r = v.re;
          ret.v_complex64.i = v.im;
        } else if (ct->bitwidth() == 128) {
          ret.num_index = COMPLEX_SIZE_128;
          ret.v_complex128.r = v.re;
          ret.v_complex128.i = v.im;
        } else {
          CHPL_ASSERT(false && "case not handled");
        }
        return ret;
      }
    case paramtags::EnumParam:
      {
        CHPL_ASSERT(false && "case not handled");
      }
    case paramtags::IntParam:
      {
        auto ip = (const IntParam*) p;
        // auto v = ip->value();
        auto it = t->toIntType();
        CHPL_ASSERT(it);
        if (it == nullptr) return ret;
        ret.const_kind = NUM_KIND_INT;
        if (it->bitwidth() == 8) {
          ret.num_index = INT_SIZE_8;
          ret.v_int8 = getImmediateValueOrEmpty<int8_t, IntParam>(ip);
        } else if (it->bitwidth() == 16) {
          ret.num_index = INT_SIZE_16;
          ret.v_int16 = getImmediateValueOrEmpty<int16_t, IntParam>(ip);
        } else if (it->bitwidth() == 32) {
          ret.num_index = INT_SIZE_32;
          ret.v_int32 = getImmediateValueOrEmpty<int32_t, IntParam>(ip);
        } else if (it->bitwidth() == 64) {
          ret.num_index = INT_SIZE_64;
          ret.v_int64 = getImmediateValueOrEmpty<int64_t, IntParam>(ip);
        } else {
          CHPL_ASSERT(false && "case not handled");
        }
        return ret;
      }
    case paramtags::NoneParam:
      {
        ret.const_kind = NUM_KIND_BOOL;
        ret.num_index = BOOL_SIZE_SYS;
        ret.v_bool = false;
        return ret;
      }
    case paramtags::RealParam:
      {
        auto rp = (const RealParam*) p;
        // auto v = rp->value();
        if (auto rt = t->toRealType()) {
          ret.const_kind = NUM_KIND_REAL;
          if (rt->bitwidth() == 32) {
            ret.num_index = FLOAT_SIZE_32;
            ret.v_float32 = getImmediateValueOrEmpty<float, RealParam>(rp);
          } else if (rt->bitwidth() == 64) {
            ret.num_index = FLOAT_SIZE_64;
            ret.v_float64 =  getImmediateValueOrEmpty<double, RealParam>(rp);
          } else {
            CHPL_ASSERT(false && "case not handled");
          }
        } else if (auto it = t->toImagType()) {
          ret.const_kind = NUM_KIND_IMAG;
          if (it->bitwidth() == 32) {
            ret.num_index = FLOAT_SIZE_32;
            ret.v_float32 = getImmediateValueOrEmpty<float, RealParam>(rp);
          } else if (it->bitwidth() == 64) {
            ret.num_index = FLOAT_SIZE_64;
            ret.v_float64 = getImmediateValueOrEmpty<double, RealParam>(rp);
          } else {
            CHPL_ASSERT(false && "case not handled");
          }
        } else {
          CHPL_ASSERT(false && "case not handled");
        }
        return ret;
      }
    case paramtags::StringParam:
      {
        auto sp = (const StringParam*) p;
        auto v = getImmediateValueOrEmpty(sp);
        ret.const_kind = CONST_KIND_STRING;
        if (t->isStringType()) {
          ret.string_kind = STRING_KIND_STRING;
          ret.num_index = 0;
          ret.v_string = v;
        } else if (t->isBytesType()) {
          ret.string_kind = STRING_KIND_BYTES;
          ret.num_index = 0;
          ret.v_string = v;
        } else if (t->isCStringType()) {
          ret.string_kind = STRING_KIND_C_STRING;
          ret.num_index = 0;
          ret.v_string = v;
        } else {
          CHPL_ASSERT(false && "case not handled");
        }
        return ret;
      }
    case paramtags::UintParam:
      {
        auto up = (const UintParam*) p;
        // auto v = up->value();
        auto ut = t->toUintType();
        CHPL_ASSERT(ut);
        if (ut == nullptr) return ret;
        ret.const_kind = NUM_KIND_UINT;
        if (ut->bitwidth() == 8) {
          ret.num_index = INT_SIZE_8;
          ret.v_uint8 = getImmediateValueOrEmpty<uint8_t, UintParam>(up);;
        } else if (ut->bitwidth() == 16) {
          ret.num_index = INT_SIZE_16;
          ret.v_uint16 = getImmediateValueOrEmpty<uint16_t, UintParam>(up);;
        } else if (ut->bitwidth() == 32) {
          ret.num_index = INT_SIZE_32;
          ret.v_uint32 = getImmediateValueOrEmpty<uint32_t, UintParam>(up);
        } else if (ut->bitwidth() == 64) {
          ret.num_index = INT_SIZE_64;
          ret.v_uint64 = getImmediateValueOrEmpty<uint64_t, UintParam>(up);
        } else {
          CHPL_ASSERT(false && "case not handled");
        }
        return ret;
      }
  }
  CHPL_ASSERT(false && "case not handled");
  return ret;
}

static
std::pair<const Param*, const Type*> immediateToParam(Context* context,
                                                      const Immediate& imm) {
  switch (imm.const_kind) {
  case NUM_KIND_INT:
    switch (imm.num_index) {
      case INT_SIZE_8:
        return {IntParam::get(context, imm.v_int8),
                IntType::get(context, 8)};
      case INT_SIZE_16:
        return {IntParam::get(context, imm.v_int16),
                IntType::get(context, 16)};
      case INT_SIZE_32:
        return {IntParam::get(context, imm.v_int32),
                IntType::get(context, 32)};
      case INT_SIZE_64:
        return {IntParam::get(context, imm.v_int64),
                IntType::get(context, 64)};
      default:
        CHPL_ASSERT(false && "case not handled");
    }
  case NUM_KIND_BOOL:
    return {BoolParam::get(context, imm.v_bool!=0), BoolType::get(context)};
  case CONST_KIND_STRING:
    switch (imm.string_kind) {
      case STRING_KIND_STRING:
        return {StringParam::get(context, imm.v_string),
                CompositeType::getStringType(context)};
      case STRING_KIND_BYTES:
        return {StringParam::get(context, imm.v_string),
                CompositeType::getBytesType(context)};
      case STRING_KIND_C_STRING:
        return {StringParam::get(context, imm.v_string),
                CStringType::get(context)};
      default:
        CHPL_ASSERT(false && "case not handled");
      }
  case NUM_KIND_REAL:
    switch (imm.num_index) {
      case FLOAT_SIZE_32:
        return {RealParam::get(context, imm.v_float32),
                RealType::get(context, 32)};
      case FLOAT_SIZE_64:
        return {RealParam::get(context, imm.v_float64),
                RealType::get(context, 64)};
      default:
        CHPL_ASSERT(false && "case not handled");
    }
  case NUM_KIND_IMAG:
    switch (imm.num_index) {
      case FLOAT_SIZE_32:
        return {RealParam::get(context, imm.v_float32),
                ImagType::get(context, 32)};
      case FLOAT_SIZE_64:
        return {RealParam::get(context, imm.v_float64),
                ImagType::get(context, 64)};
      default:
        CHPL_ASSERT(false && "case not handled");
    }
  case NUM_KIND_COMPLEX:
    switch (imm.num_index) {
      case COMPLEX_SIZE_64:
        return {ComplexParam::get(context,
                                  Param::ComplexDouble(imm.v_complex64.r,
                                                       imm.v_complex64.i)),
                ComplexType::get(context, 64)};
      case COMPLEX_SIZE_128:
        return {ComplexParam::get(context,
                                  Param::ComplexDouble(imm.v_complex128.r,
                                                       imm.v_complex128.i)),
                ComplexType::get(context, 128)};
      default:
        CHPL_ASSERT(false && "case not handled");
    }
  case NUM_KIND_UINT:
  switch (imm.num_index) {
      case INT_SIZE_8:
        return {UintParam::get(context, imm.v_uint8),
                UintType::get(context, 8)};
      case INT_SIZE_16:
        return {UintParam::get(context, imm.v_uint16),
                UintType::get(context, 16)};
      case INT_SIZE_32:
        return {UintParam::get(context, imm.v_uint32),
                UintType::get(context, 32)};
      case INT_SIZE_64:
        return {UintParam::get(context, imm.v_uint64),
                UintType::get(context, 64)};
      default:
        CHPL_ASSERT(false && "case not handled");
    }
  default:
    CHPL_ASSERT(false && "case not handled");
  }
  return {nullptr, nullptr};
}

static QualifiedType handleParamCast(Context* context,
                                     QualifiedType a,
                                     QualifiedType b) {
  // convert Param to Immediate
  Immediate aImm = paramToImmediate(a.param(), a.type());
  Immediate bImm = paramToImmediate(nullptr, b.type());

  coerce_immediate(context, &aImm, &bImm);
  std::pair<const Param*, const Type*> pair = immediateToParam(context, bImm);
  return QualifiedType(Qualifier::PARAM, pair.second, pair.first);
}

QualifiedType Param::fold(Context* context,
                          chpl::uast::PrimitiveTag op,
                          QualifiedType a,
                          QualifiedType b) {
  CHPL_ASSERT(a.hasTypePtr() && a.hasParamPtr());
  // convert Param to Immediate
  Immediate aImm = paramToImmediate(a.param(), a.type());
  Immediate result;

  // fold
  int immOp = op;

  if (op == chpl::uast::PrimitiveTag::PRIM_CAST) {
    // valid param casts should always be foldable
    return handleParamCast(context, a, b);
  }

  if (!Param::isParamOpFoldable(op)) {
    CHPL_ASSERT(false && "param primitive op not foldable");
  }

  if (b.isUnknown()) {
    fold_constant(context, immOp, &aImm, nullptr, &result);
  } else {
    CHPL_ASSERT(b.hasTypePtr() && b.hasParamPtr());

    Immediate bImm = paramToImmediate(b.param(), b.type());
    fold_constant(context, immOp, &aImm, &bImm, &result);
  }

  // convert from Immediate
  std::pair<const Param*, const Type*> pair = immediateToParam(context, result);
  return QualifiedType(Qualifier::PARAM, pair.second, pair.first);
}

void Param::stringify(std::ostream& ss, chpl::StringifyKind stringKind) const {


  switch (tag_) {
#define PARAM_NODE(NAME, VALTYPE) \
    case paramtags::NAME: { \
      const NAME* casted = (const NAME*) this; \
      auto value = casted->value(); \
      ss << Param::valueToString(value); \
      break; \
    }
// Apply the above macros to param-classes-list.h
#include "chpl/types/param-classes-list.h"
// clear the macros
#undef PARAM_NODE
  }

}

void Param::serialize(Serializer& ser) const {
  ser.write(tag_);
}

const Param* Param::deserialize(Deserializer& des) {
  ParamTag tag = des.read<ParamTag>();

  switch (tag) {
#define PARAM_NODE(NAME, VALTYPE) \
    case paramtags::NAME: { \
      return NAME::deserialize(des); \
      break; \
    }
#include "chpl/types/param-classes-list.h"
#undef PARAM_NODE
  }

  assert(false);
  return nullptr;
}

uint64_t Param::binStr2uint64(const char* str, size_t len, std::string& err) {
  if (str == nullptr ||
      !(str[0] == '0' && (str[1] == 'b' || str[1] == 'B')) ||
      stringContainsZeroBytes(str, len)) {
    CHPL_ASSERT(false && "should not be reached");
    err = "Invalid binary string";
    return 0;
  }

  CHPL_ASSERT(len >= 3);

  // Remove leading 0s
  size_t startPos = 2;
  while (str[startPos] == '0' && startPos < len-1) {
    startPos++;
  }
  // Check length
  if (len-startPos > 64) {
    err = "Integer literal overflow: '";
    err += str;
    err += "' is too big for a 64-bit unsigned integer";
    return 0;
  }
  uint64_t val = 0;
  for (size_t i=startPos; i<len; i++) {
    val <<= 1;
    switch (str[i]) {
    case '0':
      break;
    case '1':
      val += 1;
      break;
    default:
      err = "illegal character '";
      err += str[i];
      err += "' in binary literal";
      return 0;
    }
  }

  return val;
}

uint64_t Param::octStr2uint64(const char* str, size_t len, std::string& err) {
  if (str == nullptr ||
      !(str[0] == '0' && (str[1] == 'o' || str[1] == 'O')) ||
      stringContainsZeroBytes(str, len)) {
    CHPL_ASSERT(false && "should not be reached");
    err = "Invalid octal string";
    return 0;
  }

  /* Remove leading 0s */
  size_t startPos = 2;
  while (str[startPos] == '0' && startPos < len-1) {
    startPos++;
  }

  if (len-startPos > 22 || (len-startPos == 22 && str[startPos] != '1')) {
    err = "Integer literal overflow: '";
    err += str;
    err += "' is too big for a 64-bit unsigned integer";
    return 0;
  }

  for (size_t i = startPos; i < len; i++) {
    if ('0' <= str[i] && str[i] <= '8') {
      // OK
    } else {
      err = "illegal character '";
      err += str[i];
      err += "' in octal literal";
      return 0;
    }
  }

  uint64_t val;
  int numitems = sscanf(str+startPos, "%" SCNo64, &val);
  if (numitems != 1) {
    err = "error converting octal literal";
    return 0;
  }

  return val;
}

uint64_t Param::decStr2uint64(const char* str, size_t len, std::string& err) {
  if (str == nullptr ||
      str[0] == 0 ||
      stringContainsZeroBytes(str, len)) {
    CHPL_ASSERT(false && "should not be reached");
    err = "Invalid decimal string";
    return 0;
  }

  CHPL_ASSERT(len >= 1);

  /* Remove leading 0s */
  size_t startPos = 0;
  while (str[startPos] == '0' && startPos < len-1) {
    startPos++;
  }

  for (size_t i = startPos; i < len; i++) {
    if ('0' <= str[i] && str[i] <= '9') {
      // OK
    } else {
      err = "illegal character '";
      err += str[i];
      err += "' in decimal literal";
      return 0;
    }
  }

  int64_t val;
  int numitems = sscanf(str+startPos, "%" SCNu64, &val);
  if (numitems != 1) {
    err = "error converting decimal literal";
    return 0;
  }

  char* checkStr = (char*)malloc(len+1);
  snprintf(checkStr, len+1, "%" SCNu64, val);
  if (strcmp(str+startPos, checkStr) != 0) {
    err = "Integer literal overflow: '";
    err += str;
    err += "' is too big for a 64-bit unsigned integer";
    return 0;
  }
  free(checkStr);

  return val;
}

int64_t Param::decStr2int64(const char* str, size_t len, std::string& err) {
  if (str == nullptr ||
      str[0] == 0 ||
      stringContainsZeroBytes(str, len)) {
    CHPL_ASSERT(false && "should not be reached");
    err = "Invalid decimal string";
    return 0;
  }

  CHPL_ASSERT(len >= 1);

  size_t startPos = 0;
  bool negate = false;
  /* Remove leading - */
  while (str[startPos] == '-' && startPos < len-1) {
    negate = !negate;
    startPos++;
  }
  /* Remove leading 0s */
  while (str[startPos] == '0' && startPos < len-1) {
    startPos++;
  }

  for (size_t i = startPos; i < len; i++) {
    if ('0' <= str[i] && str[i] <= '9') {
      // OK
    } else {
      err = "illegal character '";
      err += str[i];
      err += "' in decimal literal";
      return 0;
    }
  }

  int64_t val;
  int numitems = sscanf(str+startPos, "%" SCNd64, &val);
  if (numitems != 1) {
    err = "error converting decimal literal";
    return 0;
  }

  char* checkStr = (char*)malloc(len+1);
  snprintf(checkStr, len+1, "%" SCNu64, val);
  if (strcmp(str+startPos, checkStr) != 0) {
    err = "Integer literal overflow: '";
    err += str;
    err += "' is too big for a 64-bit unsigned integer";
    return 0;
  }
  free(checkStr);

  if (negate)
    return -val;
  else
    return val;
}




uint64_t Param::hexStr2uint64(const char* str, size_t len, std::string &err) {
  if (str == nullptr ||
      !(str[0] == '0' && (str[1] == 'x' || str[1] == 'X')) ||
      stringContainsZeroBytes(str, len)) {
    CHPL_ASSERT(false && "should not be reached");
    err = "Invalid hexadecimal string";
    return 0;
  }

  CHPL_ASSERT(len >= 3);

  /* Remove leading 0s */
  size_t startPos = 2;
  while (str[startPos] == '0' && startPos < len-1) {
    startPos++;
  }

  if (len-startPos > 16) {
    err = "Integer literal overflow: '";
    err += str;
    err += "' is too big for a 64-bit unsigned integer";
    return 0;
  }

  for (size_t i = startPos; i < len; i++) {
    if (('0' <= str[i] && str[i] <= '9') ||
        ('a' <= str[i] && str[i] <= 'f') ||
        ('A' <= str[i] && str[i] <= 'F')) {
      // OK
    } else {
      err = "illegal character '";
      err += str[i];
      err += "' in hexadecimal literal";
      return 0;
    }
  }

  uint64_t val;
  int numitems = sscanf(str+2, "%" SCNx64, &val);
  if (numitems != 1) {
    err = "error converting hexadecimal literal";
    return 0;
  }
  return val;
}

double Param::str2double(const char* str, size_t len, std::string& err) {
  if (str == nullptr ||
      str[0] == 0 ||
      stringContainsZeroBytes(str, len)) {
    CHPL_ASSERT(false && "should not be reached");
    err = "Invalid decimal string";
    return 0;
  }

  char* endptr = nullptr;
  double num = strtod(str, &endptr);
  if (std::isnan(num) || std::isinf(num)) {
    // don't worry about checking magnitude of these
  } else {
    double mag = fabs(num);
    // check strtod result
    if ((mag == HUGE_VAL || mag == DBL_MIN) && errno == ERANGE) {
      err = "overflow or underflow in floating point literal";
      return 0.0;
    } else if (num == 0.0 && endptr == str) {
      err = "error in floating point literal";
      return 0.0;
    }
  }

  return num;
}

IMPLEMENT_DUMP(Param);

// implement the subclasses using macros and param-classes-list.h
#define PARAM_NODE(NAME, VALTYPE) \
  const owned<NAME>& NAME::get##NAME(Context* context, VALTYPE value) { \
    QUERY_BEGIN(get##NAME, context, value); \
    auto result = toOwned(new NAME(value)); \
    return QUERY_END(result); \
  }

// Apply the above macros to param-classes-list.h
#include "chpl/types/param-classes-list.h"

// clear the macros
#undef PARAM_NODE


} // end namespace types
} // end namespace chpl
