#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
/*unknown declaration named translation_unit*/
/*unknown declaration named translation_unit*/
/*unknown declaration named translation_unit*/
/*unknown declaration named translation_unit*/
/*unknown declaration named translation_unit*/
/*unknown declaration named translation_unit*/
/*unknown declaration named translation_unit*/
/*unknown declaration named translation_unit*/
/*unknown declaration named translation_unit*/
/**
 * Plain Typedefs
 */

/*typedef string */
typedef struct __struct_dummy_string__ string;
/*typedef vector */
/* non instantiated template vector *//*typedef vector<char> */
typedef struct __struct_dummy_vector_lessthan_char_greaterthan___ vector_lessthan_char_greaterthan_;
/*typedef vector<double> */
typedef struct __struct_dummy_vector_lessthan_double_greaterthan___ vector_lessthan_double_greaterthan_;
/**
 * Import Includes
 */

/**
 * Extern Variable Declarations 
 */

/**
 * Class Structs
 */

struct __struct_dummy_vector_lessthan_double_greaterthan___ {
	double* data;
	int size;
	int available;
};
struct __struct_dummy_vector_lessthan_char_greaterthan___ {
	char* data;
	int size;
	int available;
};
struct __struct_dummy_string__ {
	vector_lessthan_char_greaterthan_ data;
};
/**
 * Function Prototypes
 */


double dot_vector_lessthan_double_greaterthan__vector_lessthan_double_greaterthan_(vector_lessthan_double_greaterthan_ a, vector_lessthan_double_greaterthan_ b); /*func*/

int main(); /*func*/

void print_char_P__(char* toPrint); /*func*/

void print_string(string toPrint); /*func*/

void print_int(int toPrint); /*func*/

void print_float(float toPrint); /*func*/

void print_double(double toPrint); /*func*/

void println(); /*func*/

void println_char_P__(char* toPrint); /*func*/

void println_string(string toPrint); /*func*/

void println_int(int toPrint); /*func*/

void println_float(float toPrint); /*func*/

void println_double(double toPrint); /*func*/
/* template function delete NoValue */
/* template function delete NoValue */
/* template function delete NoValue */
/* template function delete NoValue */

void delete_lessthan_char_greaterthan__char_P__(char* toDelete); /*func*/

void delete_lessthan_char_greaterthan__char_P___int(char* toDelete, int itemCount); /*func*/

void delete_lessthan_double_greaterthan__double_P__(double* toDelete); /*func*/

void delete_lessthan_double_greaterthan__double_P___int(double* toDelete, int itemCount); /*func*/
/* template function free NoValue */
/* template function malloc NoValue */

char* malloc_lessthan_char_greaterthan__int(int size); /*func*/

double* malloc_lessthan_double_greaterthan__int(int size); /*func*/
/* template function new NoValue */
/* template function new NoValue */

char* new_lessthan_char_greaterthan__int(int count); /*func*/

double* new_lessthan_double_greaterthan__int(int count); /*func*/
/* template function sizeof NoValue */

int sizeof_lessthan_char_greaterthan_(); /*func*/

int sizeof_lessthan_double_greaterthan_(); /*func*/
/* Method Prototypes for string */

string* string__construct(string* this);

string* string__construct_char_P__(string* this, char* str);

char* string__toCharArray(string* this);
/* Done with string */
/* template function greater NoValue */
/* template function lesser NoValue */

int lesser_lessthan_int_greaterthan__int_int(int a, int b); /*func*/
/* Method Prototypes for vector<char> */

vector_lessthan_char_greaterthan_* vector_lessthan_char_greaterthan___construct(vector_lessthan_char_greaterthan_* this);

void vector_lessthan_char_greaterthan___destruct(vector_lessthan_char_greaterthan_* this);

bool vector_lessthan_char_greaterthan___resize_int(vector_lessthan_char_greaterthan_* this, int newSize);

char vector_lessthan_char_greaterthan___at_int(vector_lessthan_char_greaterthan_* this, int index);

char vector_lessthan_char_greaterthan___get_int(vector_lessthan_char_greaterthan_* this, int index);

char* vector_lessthan_char_greaterthan___getBackingMemory(vector_lessthan_char_greaterthan_* this);

void vector_lessthan_char_greaterthan___set_int_char(vector_lessthan_char_greaterthan_* this, int index, char dataIn);

void vector_lessthan_char_greaterthan___addEnd_char(vector_lessthan_char_greaterthan_* this, char dataIn);
/* Done with vector<char> */
/* Method Prototypes for vector<double> */

vector_lessthan_double_greaterthan_* vector_lessthan_double_greaterthan___construct(vector_lessthan_double_greaterthan_* this);

void vector_lessthan_double_greaterthan___destruct(vector_lessthan_double_greaterthan_* this);

bool vector_lessthan_double_greaterthan___resize_int(vector_lessthan_double_greaterthan_* this, int newSize);

double vector_lessthan_double_greaterthan___at_int(vector_lessthan_double_greaterthan_* this, int index);

double vector_lessthan_double_greaterthan___get_int(vector_lessthan_double_greaterthan_* this, int index);

double* vector_lessthan_double_greaterthan___getBackingMemory(vector_lessthan_double_greaterthan_* this);

void vector_lessthan_double_greaterthan___set_int_double(vector_lessthan_double_greaterthan_* this, int index, double dataIn);

void vector_lessthan_double_greaterthan___addEnd_double(vector_lessthan_double_greaterthan_* this, double dataIn);
/* Done with vector<double> */