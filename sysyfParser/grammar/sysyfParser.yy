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
%token PLUS MINUS MULTIPLY DIVIDE MODULO
%token ASSIGN SEMICOLON
%token LT LTE GT GTE EQ NEQ
%token COMMA LPARENTHESE RPARENTHESE
%token LBRACKET RBRACKET
%token LBRACE RBRACE
%token INT FLOAT RETURN VOID CONST
%token IF ELSE WHILE BREAK CONTINUE
%token <std::string>IDENTIFIER
%token <int>INTCONST <float>FLOATCONST
%token EOL COMMENT
%token BLANK NOT

// Use variant-based semantic values: %type and %token expect genuine types
%type <SyntaxTree::Assembly*>CompUnit
%type <SyntaxTree::PtrList<SyntaxTree::GlobalDef>>GlobalDecl
/*********add semantic value definition here*********/
%type <SyntaxTree::Type>BType 
%type <SyntaxTree::PtrList<SyntaxTree::VarDef>>VarDecl ConstDecl VarDefList ConstDefList
%type <SyntaxTree::VarDef*>VarDef ConstDef
%type <SyntaxTree::InitVal*>InitVal ConstInitVal
%type <SyntaxTree::Expr*>Exp ConstExp AddExp EqExp PrimaryExp MulExp RelExp Cond UnaryExp
%type <SyntaxTree::UnaryOp>UnaryOp
%type <SyntaxTree::PtrList<SyntaxTree::Expr>>ConstExpList ExpList 
%type <SyntaxTree::FuncDef*>FuncDef
%type <SyntaxTree::BlockStmt*>Block
%type <SyntaxTree::FuncParam*>FuncFParam
%type <SyntaxTree::FuncFParamList*>FuncFParams
%type <SyntaxTree::PtrList<SyntaxTree::Stmt>>BlockItemList BlockItem
%type <SyntaxTree::Stmt*>Stmt
%type <SyntaxTree::LVal*>LVal
%type <SyntaxTree::Literal*>Number

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

CompUnit: CompUnit GlobalDecl{
		$1->global_defs.insert($1->global_defs.end(), $2.begin(), $2.end());
		$$ = $1;
	} 
	| GlobalDecl{
		$$ = new SyntaxTree::Assembly();
		$$->global_defs.insert($$->global_defs.end(), $1.begin(), $1.end());
		$$->loc = @$;
  }
	;

CompUnit:CompUnit FuncDef{
		$1->global_defs.push_back(SyntaxTree::Ptr<SyntaxTree::GlobalDef>($2));
		$$ = $1;
	} 
	| FuncDef{
		$$ = new SyntaxTree::Assembly();
		$$->global_defs.push_back(SyntaxTree::Ptr<SyntaxTree::GlobalDef>($1));
		$$->loc = @$;
  }
	;

GlobalDecl:ConstDecl{
		$$ = SyntaxTree::PtrList<SyntaxTree::GlobalDef>();
		for (auto &node : $1) {
			$$.push_back(SyntaxTree::Ptr<SyntaxTree::GlobalDef>(node));
		}
	}
	| VarDecl{
		$$ = SyntaxTree::PtrList<SyntaxTree::GlobalDef>();
		for (auto &node : $1) {
			$$.push_back(SyntaxTree::Ptr<SyntaxTree::GlobalDef>(node));
		}
  }
	;

ConstDecl:CONST BType ConstDefList SEMICOLON{
		for (auto &node : $3){
			node->is_constant=true;
			node->btype=$2;
		}
		$$ = $3;
  }
	;

ConstDefList:ConstDefList COMMA ConstDef{
		$1.push_back(SyntaxTree::Ptr<SyntaxTree::VarDef>($3));
		$$ = $1;
  	}
	| ConstDef{
		$$ = SyntaxTree::PtrList<SyntaxTree::VarDef>();
   		$$.push_back(SyntaxTree::Ptr<SyntaxTree::VarDef>($1));
  }
	;

BType:VOID{
		$$ = SyntaxTree::Type::VOID;
	} 
	| INT{
		$$ = SyntaxTree::Type::INT;
	}
	| FLOAT{
		$$ = SyntaxTree::Type::FLOAT;
  }
	;

ConstDef:IDENTIFIER ASSIGN ConstInitVal{
		$$ = new SyntaxTree::VarDef();
		$$->name=$1;
		$$->is_constant=true;
		$$->initializers = SyntaxTree::Ptr<SyntaxTree::InitVal>($3);
		$$->is_inited=true;
		$$->loc = @$;
	}
	| IDENTIFIER LBRACKET ConstExp RBRACKET ASSIGN ConstInitVal{
		$$ = new SyntaxTree::VarDef();
		$$->name=$1;
		$$->is_constant=true;
		$$->array_length.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
		$$->initializers = SyntaxTree::Ptr<SyntaxTree::InitVal>($6);
		$$->is_inited=true;
		$$->loc = @$;
  }
	;

ConstInitVal: ConstExp{  
		$$ = new SyntaxTree::InitVal();
		$$->isExp = true;
		$$->expr = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		$$->loc = @$;
  	}
	| LBRACE RBRACE{
		$$ = new SyntaxTree::InitVal();
		$$->isExp = false;
		$$->loc = @$;	
	} 
	| LBRACE ConstExpList RBRACE{
		$$ = new SyntaxTree::InitVal();
		$$->isExp = false;
		for (auto &node : $2) {
			auto temp = new SyntaxTree::InitVal();
			temp->isExp = true;
			temp->expr = node;
			$$->elementList.push_back(SyntaxTree::Ptr<SyntaxTree::InitVal>(temp));
		}
		$$->loc = @$;
  } 
	;

ConstExpList:ConstExpList COMMA ConstExp{
		$1.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
		$$=$1;
  	}
	| ConstExp{
		$$=SyntaxTree::PtrList<SyntaxTree::Expr>();
   		$$.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($1));
  }
	;

VarDecl:BType VarDefList SEMICOLON{
		for (auto &node : $2){
			node->is_constant=false;
			node->btype=$1;
		}
		$$ = $2;
  }
	;

VarDefList:VarDefList COMMA VarDef{
		$1.push_back(SyntaxTree::Ptr<SyntaxTree::VarDef>($3));
		$$ = $1;
  	}
	| VarDef{
		$$ = SyntaxTree::PtrList<SyntaxTree::VarDef>();
   		$$.push_back(SyntaxTree::Ptr<SyntaxTree::VarDef>($1));
  }
	;

VarDef: IDENTIFIER LBRACKET ConstExp RBRACKET{
		$$=new SyntaxTree::VarDef();
		$$->name=$1;
		$$->is_constant=false;
		$$->array_length.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
		$$->is_inited=false;
		$$->loc = @$;
  	} 
  	| IDENTIFIER{
		$$=new SyntaxTree::VarDef();
		$$->name=$1;
		$$->is_constant=false;
		$$->is_inited=false;
		$$->loc = @$;
	}
	| IDENTIFIER LBRACKET ConstExp RBRACKET ASSIGN InitVal{
		$$=new SyntaxTree::VarDef();
		$$->name=$1;
		$$->is_constant=false;
		$$->array_length.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
		$$->initializers = SyntaxTree::Ptr<SyntaxTree::InitVal>($6);
		$$->is_inited=true;
		$$->loc = @$;
  	}	
	| IDENTIFIER ASSIGN InitVal{
		$$=new SyntaxTree::VarDef();
		$$->name=$1;
		$$->is_constant=false;
		$$->initializers = SyntaxTree::Ptr<SyntaxTree::InitVal>($3);
		$$->is_inited=true;
		$$->loc = @$;
  }
	;

InitVal:Exp{
		$$ = new SyntaxTree::InitVal();
		$$->isExp = true;
		$$->expr = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		$$->loc = @$;
  	}
  	| LBRACE RBRACE{
		$$ = new SyntaxTree::InitVal();
		$$->isExp = false;
		$$->loc = @$;
 	}
	| LBRACE ExpList RBRACE{
		$$ = new SyntaxTree::InitVal();
		$$->isExp = false;
		for (auto &node : $2) {
			auto temp = new SyntaxTree::InitVal();
			temp->isExp = true;
			temp->expr = node;
			$$->elementList.push_back(SyntaxTree::Ptr<SyntaxTree::InitVal>(temp));
		}
		$$->loc = @$;
  }
	;

ExpList:ExpList COMMA Exp{
		$1.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
		$$=$1;
	}
	| Exp{
		$$=SyntaxTree::PtrList<SyntaxTree::Expr>();
   		$$.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($1));
  }
	;

FuncDef:BType IDENTIFIER LPARENTHESE FuncFParams RPARENTHESE Block{
		$$ = new SyntaxTree::FuncDef();
		$$->ret_type = $1;
		$$->name = $2;   
    if ($4->params.size() > 0)
		  $$->param_list = SyntaxTree::Ptr<SyntaxTree::FuncFParamList>($4);
		$$->body = SyntaxTree::Ptr<SyntaxTree::BlockStmt>($6);
		$$->loc = @$;
  }
	;

FuncFParams:FuncFParam{
		$$ = new SyntaxTree::FuncFParamList();
    if (len($1->name)>0)
		  $$->params.push_back(SyntaxTree::Ptr<SyntaxTree::FuncParam>($1));
		$$->loc = @$;
  }
	;

FuncFParam: %empty{
    $$ = new SyntaxTree::FuncParam();
    $$->loc = @$;
  }
  | BType IDENTIFIER{
    $$ = new SyntaxTree::FuncParam();
    $$->param_type = $1;
    $$->name = $2;
  }
  ;

Block:LBRACE BlockItemList RBRACE{
		$$ = new SyntaxTree::BlockStmt();
		$$->body = $2;
		$$->loc = @$;
  }
	;

BlockItemList:BlockItemList BlockItem{
		$1.insert($1.end(), $2.begin(), $2.end());
		$$ = $1;
  	}
  	| %empty{
    	$$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
  }
  	;

BlockItem: ConstDecl{
		$$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
   		$$.insert($$.end(), $1.begin(), $1.end());
	}
	| VarDecl{
		$$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
		$$.insert($$.end(), $1.begin(), $1.end());
	}
	| Stmt{
		$$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
    	$$.push_back(SyntaxTree::Ptr<SyntaxTree::Stmt>($1));
  }
	;

Stmt:LVal ASSIGN Exp SEMICOLON{
		auto temp = new SyntaxTree::AssignStmt();
		temp->target = SyntaxTree::Ptr<SyntaxTree::LVal>($1);
		temp->value = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
	}
	| Exp SEMICOLON{
		auto temp= new SyntaxTree::ExprStmt();
		temp->exp = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		$$ = temp;
		$$->loc = @$;
	}
	| SEMICOLON{
		$$ = new SyntaxTree::EmptyStmt();
		$$->loc = @$;
	}
	| Block{
		$$ = $1;
	}
	| IF LPARENTHESE Cond RPARENTHESE Stmt ELSE Stmt{
		auto temp = new SyntaxTree::IfStmt();
		temp->cond_exp = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		temp->if_statement = SyntaxTree::Ptr<SyntaxTree::Stmt>($5);
		temp->else_statement = SyntaxTree::Ptr<SyntaxTree::Stmt>($7);
		$$ = temp;
		$$->loc = @$;
	}
	| IF LPARENTHESE Cond RPARENTHESE Stmt{
		auto temp = new SyntaxTree::IfStmt();
		temp->cond_exp = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		temp->if_statement = SyntaxTree::Ptr<SyntaxTree::Stmt>($5);
		$$ = temp; 
		$$->loc = @$;
	}
	| WHILE LPARENTHESE Cond RPARENTHESE Stmt{
		auto temp = new SyntaxTree::WhileStmt();
		temp->cond_exp = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		temp->statement = SyntaxTree::Ptr<SyntaxTree::Stmt>($5);
		$$ = temp;
		$$->loc = @$;
	}
	| BREAK SEMICOLON{
		$$ = new SyntaxTree::BreakStmt();
	}
	| CONTINUE SEMICOLON{
		$$ = new SyntaxTree::ContinueStmt();
	}
	| RETURN SEMICOLON{
		$$ = new SyntaxTree::ReturnStmt();
	}
	| RETURN Exp SEMICOLON{
		auto temp = new SyntaxTree::ReturnStmt();
		temp->ret = SyntaxTree::Ptr<SyntaxTree::Expr>($2);
		$$ = temp;
		$$->loc = @$;
  }
	;

%left PLUS MINUS;
%left MULTIPLY DIVIDE MODULO;
%precedence UPLUS UMINUS;

Exp:AddExp{
		$$ = $1;
  }
	;

Cond:EqExp{
		$$ = $1;
  }
	;

LVal: IDENTIFIER LBRACKET Exp RBRACKET{
		$$ = new SyntaxTree::LVal();
		$$->name = $1;
		$$->array_index.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
		$$->loc = @$;
  	}
	| IDENTIFIER{
		$$ = new SyntaxTree::LVal();
		$$->name = $1;
		$$->loc = @$;
  }
	;

PrimaryExp:LPARENTHESE Exp RPARENTHESE{
		$$ = $2;
	}
	| LVal{
		$$ = $1;
	}
	| Number{
		$$ = $1;
  }	
	;

Number:INTCONST{
		$$ = new SyntaxTree::Literal();
		$$->literal_type = SyntaxTree::Type::INT;
		$$->int_const = $1;
		$$->loc = @$;
	}
	| FLOATCONST{
		$$ = new SyntaxTree::Literal();
		$$->literal_type = SyntaxTree::Type::FLOAT;
		$$->float_const = $1;
		$$->loc = @$;
  }
	;

UnaryExp: PrimaryExp{
		$$ = $1;
  	}
	| IDENTIFIER LPARENTHESE RPARENTHESE{
		auto temp = new SyntaxTree::LVal();
		temp->name = $1;
		temp->loc = @$;
		$$ = temp;
		$$->loc = @$;
	}
	| UnaryOp UnaryExp{
		auto temp = new SyntaxTree::UnaryExpr();
		temp->op = SyntaxTree::UnaryOp($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($2);
		$$ = temp;
		$$->loc = @$;
  }
	;

UnaryOp:PLUS %prec UPLUS{
		$$ = SyntaxTree::UnaryOp::PLUS;
	}
	| MINUS %prec UMINUS{
		$$ = SyntaxTree::UnaryOp::MINUS;
  }
	;

MulExp: UnaryExp{
		$$ = $1;
  	}	 
  	| MulExp MULTIPLY UnaryExp{
		auto temp = new SyntaxTree::BinaryExpr();
		temp->op = SyntaxTree::BinOp::MULTIPLY;
		temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
	}
	| MulExp DIVIDE UnaryExp{
		auto temp = new SyntaxTree::BinaryExpr();
		temp->op = SyntaxTree::BinOp::DIVIDE;
		temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
	}
	| MulExp MODULO UnaryExp{
		auto temp = new SyntaxTree::BinaryExpr();
		temp->op = SyntaxTree::BinOp::MODULO;
		temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
  }
	;

AddExp:	MulExp{
		$$ = $1;
 	}
  	| AddExp PLUS MulExp{
		auto temp = new SyntaxTree::BinaryExpr();
		temp->op = SyntaxTree::BinOp::PLUS;
		temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
	}
	| AddExp MINUS MulExp{
		auto temp = new SyntaxTree::BinaryExpr();
		temp->op = SyntaxTree::BinOp::MINUS;
		temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
  }
	;

RelExp: AddExp{
		$$ = $1;
  	}
	| RelExp LT AddExp{
		auto temp = new SyntaxTree::BinaryCondExpr();
		temp->op = SyntaxTree::BinaryCondOp::LT;
		temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
	}
	| RelExp LTE AddExp{
		auto temp = new SyntaxTree::BinaryCondExpr();
		temp->op = SyntaxTree::BinaryCondOp::LTE;
		temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
	}
	| RelExp GT AddExp{
		auto temp = new SyntaxTree::BinaryCondExpr();
		temp->op = SyntaxTree::BinaryCondOp::GT;
		temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
	}
	| RelExp GTE AddExp{
		auto temp = new SyntaxTree::BinaryCondExpr();
		temp->op = SyntaxTree::BinaryCondOp::GTE;
		temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
  }
	;

EqExp:RelExp{
		$$ = $1;
  	}		
  	| EqExp EQ RelExp{
		auto temp= new SyntaxTree::BinaryCondExpr();
		temp->op = SyntaxTree::BinaryCondOp::EQ;
		temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
	}
	| EqExp NEQ RelExp{
		auto temp= new SyntaxTree::BinaryCondExpr();
		temp->op = SyntaxTree::BinaryCondOp::NEQ;
		temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
		temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
		$$ = temp;
		$$->loc = @$;
  } 
  	;

ConstExp:AddExp{
		$$ = $1;
  }
	;

%%

// Register errors to the driver:
void yy::sysyfParser::error (const location_type& l,
                          const std::string& m)
{
    driver.error(l, m);
}
