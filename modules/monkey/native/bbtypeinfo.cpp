
#include "bbtypeinfo.h"
#include "bbdeclinfo.h"

namespace{

	bbClassTypeInfo *_classes;
}

// ***** bbTypeInfo *****

bbString bbTypeInfo::toString(){
	return name;
}

bbTypeInfo *bbTypeInfo::pointeeType(){
	bbRuntimeError( "Type '"+name+"' is not a pointer type" );
	return 0; 
}
	
bbTypeInfo *bbTypeInfo::elementType(){
	bbRuntimeError( "Type '"+name+"' is not an array type" );
	return 0;
}
	
int bbTypeInfo::arrayRank(){
	bbRuntimeError( "Type '"+name+"' is not an array type" );
	return 0;
}
	
bbTypeInfo *bbTypeInfo::returnType(){
	bbRuntimeError( "Type '"+name+"' is not a function type" );
	return 0; 
}
	
bbArray<bbTypeInfo*> bbTypeInfo::paramTypes(){
	bbRuntimeError( "Type '"+name+"' is not a function type" );
	return {};
}
	
bbTypeInfo *bbTypeInfo::superType(){
	bbRuntimeError( "Type '"+name+"' is not a class type" );
	return 0;
}
	
bbBool bbTypeInfo::extendsType( bbTypeInfo *type ){
	bbRuntimeError( "Type '"+name+"' is not a class type" );
	return false;
}
	
bbArray<bbDeclInfo*> bbTypeInfo::getDecls(){
	bbRuntimeError( "Type '"+name+"' is not a class type" );
	return {};
}

bbDeclInfo *bbTypeInfo::getDecl( bbString name ){

	bbArray<bbDeclInfo*> decls=getDecls();
	bbDeclInfo *found=0;

	for( int i=0;i<decls.length();++i ){
		bbDeclInfo *decl=decls[i];
		if( decl->name!=name ) continue;
		if( found ) return 0;
		found=decl;
	}

	return found;
}

bbArray<bbDeclInfo*> bbTypeInfo::getDecls( bbString name ){

	bbArray<bbDeclInfo*> decls=getDecls();

	int n=0;
	for( int i=0;i<decls.length();++i ){
		if( decls[i]->name==name ) ++n;
	}
	if( !n ) return {};
	
	bbArray<bbDeclInfo*> rdecls;
	
	int j=0;
	for( int i=0;i<decls.length();++i ){
		if( decls[i]->name==name) rdecls[j++]=decls[i];
	}
	return rdecls;
}

bbDeclInfo *bbTypeInfo::getDecl( bbString name,bbTypeInfo *type ){

	bbArray<bbDeclInfo*> decls=getDecls();

	for( int i=0;i<decls.length();++i ){
		bbDeclInfo *decl=decls[i];
		if( decl->name==name && decl->type==type ) return decl;
	}
	
	return 0;
}

bbTypeInfo *bbTypeInfo::getType( bbString cname ){

	for( bbClassTypeInfo *c=_classes;c;c=c->_succ ){
		if( c->name==cname ) return c;
	}
	
	return 0;
}

bbArray<bbTypeInfo*> bbTypeInfo::getTypes(){

	int n=0;
	for( bbClassTypeInfo *c=_classes;c;c=c->_succ ) ++n;
	
	bbArray<bbTypeInfo*> types( n );
	
	int i=0;
	for( bbClassTypeInfo *c=_classes;c;c=c->_succ ) types[i++]=c;
	
	return types;
}


// ***** bbUnknownTypeInfo *****

bbUnknownTypeInfo::bbUnknownTypeInfo(){
	this->name=BB_T("Unknown@")+bbString( bbLong( this ) );
	this->kind="Unknown";
}


// ***** bbVoidTypeInfo *****

bbVoidTypeInfo bbVoidTypeInfo::instance;

bbVoidTypeInfo::bbVoidTypeInfo(){
	this->name="Void";
	this->kind="Void";
}


// ***** bbObjectTypeInfo *****

bbObjectTypeInfo bbObjectTypeInfo::instance;

bbObjectTypeInfo::bbObjectTypeInfo(){
	this->name="Object";
	this->kind="Class";
}
	
bbTypeInfo *bbObjectTypeInfo::superType(){
	return 0;
}
	
bbBool bbObjectTypeInfo::extendsType( bbTypeInfo *type ){
	return type==&instance;
}
	
bbArray<bbDeclInfo*> bbObjectTypeInfo::getDecls(){
	return {};
}

bbTypeInfo *bbObject::typeof()const{

	return &bbObjectTypeInfo::instance;
}


// ***** bbPrimTypeInfo *****

bbPrimTypeInfo::bbPrimTypeInfo( bbString name ){
	this->name=name;
	this->kind="Primitive";
}


// ***** bbClassDecls *****

bbClassDecls::bbClassDecls( bbClassTypeInfo *classType ){
	_succ=classType->_decls;
	classType->_decls=this;
}

bbDeclInfo **bbClassDecls::decls(){

	if( !_decls ){
		_decls=initDecls();
		bbDeclInfo **p=_decls;
		while( *p ) ++p;
		_numDecls=p-_decls;
	}
	
	return _decls;
}

int bbClassDecls::numDecls(){
	if( !_decls ) decls();
	return _numDecls;
}

// ***** bbClassTypeInfo *****

bbClassTypeInfo::bbClassTypeInfo( bbString name,bbString kind ){
//	printf( "ClassTypeInfo:%s\n",name.c_str() );
	this->name=name;
	this->kind=kind;
	_succ=_classes;
	_classes=this;
}

bbBool bbClassTypeInfo::extendsType( bbTypeInfo *type ){
	if( type==this ) return true;
	if( bbTypeInfo *super=superType() ) return super->extendsType( type );
	return false;
}

bbArray<bbDeclInfo*> bbClassTypeInfo::getDecls(){

	int n=0;
	for( bbClassDecls *m=_decls;m;m=m->_succ ) n+=m->numDecls();
	
	bbArray<bbDeclInfo*> rdecls( n );
	
	int i=0;
	for( bbClassDecls *m=_decls;m;m=m->_succ ){
		bbDeclInfo **decls=m->decls();
		int n=m->numDecls();
		for( int j=0;j<n;++j ) rdecls[i++]=decls[j];
	}
	
	return rdecls;
}

bbClassTypeInfo *bbClassTypeInfo::getNamespace( bbString name ){

	for( bbClassTypeInfo *nmspace=_classes;nmspace;nmspace=nmspace->_succ ){
		if( nmspace->name==name ) return nmspace;
	}
	
	bbClassTypeInfo *nmspace=new bbClassTypeInfo( name,"Namespace" );
	return nmspace;
}