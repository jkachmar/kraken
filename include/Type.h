#ifndef TYPE_H
#define TYPE_H

#ifndef NULL
#define NULL ((void*)0)
#endif

#include <string>
#include <iostream>

//Circular dependency
class ASTData;
#include "ASTData.h"
#include "util.h"

enum ValueType {none, void_type, boolean, integer, floating, double_percision, character };


class Type {
	public:
		Type();
		Type(ValueType typeIn, int indirectionIn);
		Type(ValueType typeIn);
		Type(NodeTree<ASTData>* typeDefinitionIn);
		Type(NodeTree<ASTData>* typeDefinitionIn, int indirectionIn);
		Type(ValueType typeIn, NodeTree<ASTData>* typeDefinitionIn, int indirectionIn);
		~Type();
		bool const operator==(const Type &other)const;
		bool const operator!=(const Type &other)const;
		std::string toString();
		ValueType baseType;
		NodeTree<ASTData>* typeDefinition;
		int indirection;
	private:
};

#endif