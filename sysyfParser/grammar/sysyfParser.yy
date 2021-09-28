%skeleton "lalr1.cc" /* -*- c++ -*- */
%require "3.0"
%defines
//%define parser_class_name {sysyfParser}
%define api.parser.class {sysyfParser}

%define api.token.constructor
%define api.value.type variant
%define parse.assert

%code requires
{
#include <string>
#include "SyntaxTree.h"
class sysyfDriver;
}

// The parsing context.
%param { sysyfDriver& driver }

// Location tracking
%locations
%initial-action
{
// Initialize the initial location.
@$.begin.filename = @$.end.filename = &driver.file;
};

// Enable tracing and verbose errors (which may be wrong!)
%define parse.trace
%define parse.error verbose

// Parser needs to know about the driver:
%code
{
#include "sysyfDriver.h"
#define yylex driver.lexer.yylex
}

// Tokens:
%define api.token.prefix {TOK_}

%token END
/*********add your token here*********/


// Use variant-based semantic values: %type and %token expect genuine types
%type <SyntaxTree::Assembly*>CompUnit
%type <SyntaxTree::PtrList<SyntaxTree::GlobalDef>>GlobalDecl
/*********add semantic value definition here*********/


// No %destructors are needed, since memory will be reclaimed by the
// regular destructors.

// Grammar:
%start Begin 

%%
Begin: CompUnit END {
    $1->loc = @$;
    driver.root = $1;
    return 0;
  }
  ;

CompUnit:CompUnit GlobalDecl{
		$1->global_defs.insert($1->global_defs.end(), $2.begin(), $2.end());
		$$=$1;
	} 
	| GlobalDecl{
		$$=new SyntaxTree::Assembly();
		$$->global_defs.insert($$->global_defs.end(), $1.begin(), $1.end());
  }
	;

/*********add other semantic symbol definition here*********/

%%

// Register errors to the driver:
void yy::sysyfParser::error (const location_type& l,
                          const std::string& m)
{
    driver.error(l, m);
}
