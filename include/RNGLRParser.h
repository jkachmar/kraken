#ifndef RNGLRPARSER_H
#define RNGLRPARSER_H

#include <iostream>
#include <queue>
#include <map>
#include <vector>
#include <algorithm>
#include "Parser.h"
#include "Symbol.h"
#include "GraphStructuredStack.h"
#include "util.h"

class RNGLRParser: public Parser {
	public:
		RNGLRParser();
		~RNGLRParser();
		NodeTree<Symbol*>* parseInput(std::string inputString);

	private:
		void reducer(int i);
		void shifter(int i);
		void addChildren(NodeTree<Symbol*>* parent, std::vector<NodeTree<Symbol*>*>* children, int nullablePartsIndex);

		void addStates(std::vector< State* >* stateSets, State* state);
		bool reducesToNull(ParseRule* rule);
		bool reducesToNull(ParseRule* rule, std::vector<Symbol*> avoidList);

		bool belongsToFamily(NodeTree<Symbol*>* node, std::vector<NodeTree<Symbol*>*>* nodes);
		bool arePacked(std::vector<NodeTree<Symbol*>*> nodes);
		bool isPacked(NodeTree<Symbol*>* node);
		void setPacked(NodeTree<Symbol*>* node, bool isPacked);

		int getNullableIndex(ParseRule* rule);
		NodeTree<Symbol*>* getNullableParts(ParseRule* rule);
		NodeTree<Symbol*>* getNullableParts(Symbol* symbol);
		NodeTree<Symbol*>* getNullableParts(int index);

		std::vector<NodeTree<Symbol*>*> getPathEdges(std::vector<NodeTree<int>*> path);

		std::vector<Symbol*> input;
		GraphStructuredStack gss;
		//start node, lefthand side of the reduction, reduction length
		struct Reduction {
			NodeTree<int>* from;
			Symbol* symbol;
			int length;
			int nullablePartsIndex;
			NodeTree<Symbol*>* label;
		} ;
		std::queue<Reduction> toReduce;
		//Node coming from, state going to
		std::queue< std::pair<NodeTree<int>*, int> > toShift;
		std::vector<std::pair<NodeTree<Symbol*>*, int> > SPPFStepNodes;

		std::vector<NodeTree<Symbol*>*> nullableParts;
		std::map<NodeTree<Symbol*>, bool> packedMap;
};

#endif