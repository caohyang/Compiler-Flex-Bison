%{ /* -*- C++ -*- */
# include <cerrno>
# include <climits>
# include <cstdlib>
# include <cstring> // strerror
# include <string>
# include <algorithm>
# include <iostream>
# include <map>
# include "sysyfDriver.h"
# include "sysyfParser.h"
%}

%{ 
#if defined __clang__
# define CLANG_VERSION (__clang_major__ * 100 + __clang_minor__)
#endif

// Clang and ICC like to pretend they are GCC.
#if defined __GNUC__ && !defined __clang__ && !defined __ICC
# define GCC_VERSION (__GNUC__ * 100 + __GNUC_MINOR__)
#endif

// Pacify warnings in yy_init_buffer (observed with Flex 2.6.4)
// and GCC 6.4.0, 7.3.0 with -O3.
#if defined GCC_VERSION && 600 <= GCC_VERSION
# pragma GCC diagnostic ignored "-Wnull-dereference"
#endif

// This code uses Flex's C backend, yet compiles it as C++.
// So expect warnings about C style casts and NULL.
#if defined CLANG_VERSION && 500 <= CLANG_VERSION
# pragma clang diagnostic ignored "-Wold-style-cast"
# pragma clang diagnostic ignored "-Wzero-as-null-pointer-constant"
#elif defined GCC_VERSION && 407 <= GCC_VERSION
# pragma GCC diagnostic ignored "-Wold-style-cast"
# pragma GCC diagnostic ignored "-Wzero-as-null-pointer-constant"
#endif

#define FLEX_VERSION (YY_FLEX_MAJOR_VERSION * 100 + YY_FLEX_MINOR_VERSION)

// Old versions of Flex (2.5.35) generate an incomplete documentation comment.
//
//  In file included from src/scan-code-c.c:3:
//  src/scan-code.c:2198:21: error: empty paragraph passed to '@param' command
//        [-Werror,-Wdocumentation]
//   * @param line_number
//     ~~~~~~~~~~~~~~~~~^
//  1 error generated.
#if FLEX_VERSION < 206 && defined CLANG_VERSION
# pragma clang diagnostic ignored "-Wdocumentation"
#endif

// Old versions of Flex (2.5.35) use 'register'.  Warnings introduced in
// GCC 7 and Clang 6.
#if FLEX_VERSION < 206
# if defined CLANG_VERSION && 600 <= CLANG_VERSION
#  pragma clang diagnostic ignored "-Wdeprecated-register"
# elif defined GCC_VERSION && 700 <= GCC_VERSION
#  pragma GCC diagnostic ignored "-Wregister"
# endif
#endif

#if FLEX_VERSION < 206
# if defined CLANG_VERSION
#  pragma clang diagnostic ignored "-Wconversion"
#  pragma clang diagnostic ignored "-Wdocumentation"
#  pragma clang diagnostic ignored "-Wshorten-64-to-32"
#  pragma clang diagnostic ignored "-Wsign-conversion"
# elif defined GCC_VERSION
#  pragma GCC diagnostic ignored "-Wconversion"
#  pragma GCC diagnostic ignored "-Wsign-conversion"
# endif
#endif
%}

%option noyywrap nounput noinput batch debug

%{
  // Code run each time a pattern is matched.
  # define YY_USER_ACTION  loc.columns(yyleng);
%}

/* Regex abbreviations: */
/********add regular expression for MultilineComment, HexConst, FloatConst, SingleLineComment********/
MultiLineComment	    \/\*(\s|.)*?\*\/
SingleLineComment	    \/\/[^\n]*
Identifier              [_a-zA-Z][a-zA-Z0-9_]*
OctConst                ("0"[0-7]*)
DecConst                ([1-9][0-9]*)
HexConst                ("0x"|"0X")[0-9A-Fa-f]+
FloatConst              [1-9][0-9]*.[0-9]+(("E"|"e")("+"|"-")?[0-9]+)?
Blank                   [ \t\r]
NewLine                 [\n]

%%

int         {return yy::sysyfParser::make_INT(loc);} 
return      {return yy::sysyfParser::make_RETURN(loc);}
float       {return yy::sysyfParser::make_FLOAT(loc);}
void        {return yy::sysyfParser::make_VOID(loc);}
const       {return yy::sysyfParser::make_CONST(loc);}
if          {return yy::sysyfParser::make_IF(loc);}
else        {return yy::sysyfParser::make_ELSE(loc);}
while       {return yy::sysyfParser::make_WHILE(loc);}
break       {return yy::sysyfParser::make_BREAK(loc);}
continue    {return yy::sysyfParser::make_CONTINUE(loc);}

(<=)        {return yy::sysyfParser::make_LTE(loc);}
(>=)        {return yy::sysyfParser::make_GTE(loc);}
(==)        {return yy::sysyfParser::make_EQ(loc);} 
(!=)        {return yy::sysyfParser::make_NEQ(loc);}
[<]         {return yy::sysyfParser::make_LT(loc);}
[>]         {return yy::sysyfParser::make_GT(loc);}

[+]         {return yy::sysyfParser::make_PLUS(loc);}
[-]         {return yy::sysyfParser::make_MINUS(loc);}
[*]         {return yy::sysyfParser::make_MULTIPLY(loc);}
[/]         {return yy::sysyfParser::make_DIVIDE(loc);}
[%]         {return yy::sysyfParser::make_MODULO(loc);}
[=]         {return yy::sysyfParser::make_ASSIGN(loc);}
[;]         {return yy::sysyfParser::make_SEMICOLON(loc);}
[,]         {return yy::sysyfParser::make_COMMA(loc);}
[(]         {return yy::sysyfParser::make_LPARENTHESE(loc);}
[)]         {return yy::sysyfParser::make_RPARENTHESE(loc);}
[[]         {return yy::sysyfParser::make_LBRACKET(loc);}
[]]         {return yy::sysyfParser::make_RBRACKET(loc);}
[{]         {return yy::sysyfParser::make_LBRACE(loc);}
[}]         {return yy::sysyfParser::make_RBRACE(loc);}

{MultiLineComment}      {loc.step();}
{SingleLineComment}     {loc.step();}
{Blank}+                {loc.step();}
{NewLine}+              {loc.lines(yyleng); loc.step();}
{DecConst}              {
                            std::string dec = yytext;
                            unsigned sum = 0;
                            int len = dec.size();
                            for(int i = 0;i < len;i++){
                                auto a = dec[i];
                                sum = sum * 10 + a - 48;
                            }
                            return yy::sysyfParser::make_INTCONST(int(sum),loc);
                        }
{OctConst}              {
                            std::string oct = yytext;
                            unsigned sum = 0;
                            int len = oct.size();
                            for(int i = 1;i < len;i++){
                                auto a = oct[i];
                                sum  = sum * 8 + a - 48;
                            }
                            return yy::sysyfParser::make_INTCONST(int(sum),loc);
                        }
{HexConst}              {
                            std::string hex = yytext;
                            unsigned sum = 0;
                            int len = hex.size();
                            for(int i = 2;i < len;i++){
                                auto a = hex[i];
                                if (a >= 48 && a <= 57)
                                    sum  = sum * 16 + a - 48;
                                else if (a >= 65 && a <= 90)
                                    sum = sum * 16 + a - 55;
                                else
                                    sum  = sum * 16 + a - 87;
                            }
                            return yy::sysyfParser::make_INTCONST(int(sum),loc);
                        }
{FloatConst}             {
                            std::string fl = yytext;
                            float sum = 0;
                            int i, pow, len = fl.size();
                            for(i = 0;i < len && fl[i] != '.';i++){
                                auto a = fl[i];
                                sum  = sum * 10 + a - 48;
                            }
                            if (i < len){
                                float sum1 = 0;
                                float p = 1;
                                i++;
                                for(;i < len && fl[i] != 'E' && fl[i] != 'e';i++){
                                    p = p * 1.0 / 10;
                                    auto a = fl[i];
                                    sum1  = sum1 + (a - 48) * p;
                                }
                                sum = sum + sum1;
                                if (i < len){
                                    pow = 0;
                                    i++;
                                    if (fl[i] == '-'){
                                        i++;
                                        for(;i < len;i++){
                                            auto a = fl[i];
                                            pow  = pow * 10 + a - 48;
                                        }
                                        pow *= -1;           
                                    }
                                    else{
                                        for(;i < len;i++){
                                            auto a = fl[i];
                                            pow  = pow * 10 + a - 48;
                                        }                        
                                    }
                                    if (pow < 0){
                                        for (i = pow;i < 0; i++)
                                            sum /= 10;
                                    }
                                    else{
                                        for (i = 0;i < pow; i++)
                                            sum *= 10;
                                    }
                                }
                            }
                            return yy::sysyfParser::make_FLOATCONST(sum,loc);
                        }
{Identifier}            {return yy::sysyfParser::make_IDENTIFIER(yytext, loc);}
<<EOF>>                 {return yy::sysyfParser::make_END(loc);}
.                       {std::cout << "Error in scanner!" << '\n'; exit(1);}

%%

int yyFlexLexer::yylex() {
    std::cerr << "'int yyFlexLexer::yylex()' should never be called." << std::endl;
    exit(1);
}

