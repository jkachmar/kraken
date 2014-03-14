#include "Type.h"

Type::Type() {
	indirection = 0;
	baseType = none;
	typeDefinition = NULL;
}

Type::Type(ValueType typeIn) {
	indirection = 0;
	baseType = typeIn;
	typeDefinition = NULL;
}

Type::Type(ValueType typeIn, int indirectionIn) {
	indirection = indirectionIn;
	baseType = typeIn;
	typeDefinition = NULL;
}

Type::Type(NodeTree<ASTData>* typeDefinitionIn) {
	indirection = 0;
	baseType = none;
	typeDefinition = typeDefinitionIn;
}
Type::Type(NodeTree<ASTData>* typeDefinitionIn, int indirectionIn) {
	indirection = indirectionIn;
	baseType = none;
	typeDefinition = typeDefinitionIn;
}

Type::Type(ValueType typeIn, NodeTree<ASTData>* typeDefinitionIn, int indirectionIn) {
	baseType = typeIn;
	indirection = indirectionIn;
	typeDefinition = typeDefinitionIn;
}

Type::~Type() {
}

const bool Type::operator==(const Type &other) const {
	return( baseType == other.baseType && indirection == other.indirection && typeDefinition == other.typeDefinition);
}

const bool Type::operator!=(const Type &other) const {
	return(!this->operator==(other));
}

std::string Type::toString() {
	std::string typeString;
	switch (baseType) {
		case none:
			if (typeDefinition)
				typeString = typeDefinition->getDataRef()->symbol.getName();
			else
				typeString = "none";
			break;
		case void_type:
			typeString = "void";
			break;
		case boolean:
			typeString = "bool";
			break;
		case integer:
			typeString = "int";
			break;
		case floating:
			typeString = "float";
			break;
		case double_percision:
			typeString = "double";
			break;
		case character:
			typeString = "char";
			break;
		default:
			if (typeDefinition)
				typeString = typeDefinition->getDataRef()->symbol.getName();
			else
				typeString = "unknown_type";
	}
	for (int i = 0; i < indirection; i++)
		typeString += "*";
	return typeString;
}