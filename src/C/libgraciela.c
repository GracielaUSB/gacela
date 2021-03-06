/* graciela-lib
$ gcc -fPIC -shared graciela-lib.c -o graciela-lib.so
$ clang -fPIC -shared graciela-lib.c -o graciela-lib.so
*/

#include "math.h"
#include "stdio.h"
#include "limits.h"
#include "stdlib.h"
#include "wchar.h"
#include "locale.h"
#include "string.h"
#include "libgraciela-abstract/libgraciela-abstract.h"

int8_t* _openFile(char* name) {
  FILE* file;

  file = fopen(name, "r");
  if(file == NULL)
  {
    printf ("\x1B[0;31mError:\x1B[m Could not open file `%s`\n", name);
    exit(EXIT_FAILURE);
  }
  return (int8_t *) file;
}

void _closeFile(int8_t* file) {
  FILE* f = (FILE*) file;
  fclose(f);
}

int8_t* _malloc(int size){  
  int8_t* p = calloc(1,size);
  if (!p) {
    printf("\x1B[0;31mError:\x1B[m Out of memory.");
    exit(EXIT_FAILURE);
  }
  _addPointer(p);
  return p;

}

int8_t* _mallocTC(int size){
  int8_t* p = calloc(1,size);
  if (!p) {
    printf("\x1B[0;31mError:\x1B[m Could not initialize the TC module. Out of memory.");
    exit(EXIT_FAILURE);
  }
  _mark(p);
  return p;
}


void _free(int8_t *mem, int l, int c){
  _removePointer(mem, l ,c);
  free(mem);
}

int _readFileInt(int8_t* file) {
  FILE* f = (FILE*) file;

  int n;
  int r = fscanf(f, "%d", &n);

  if (r == EOF)
  {
    printf ("\x1B[0;31mError:\x1B[m End of file reached while reading a file\n");
    exit(EXIT_FAILURE);
  }
  if (r == 0)
  {
    printf ("\x1B[0;31mError:\x1B[m The value read from file is not of type \x1B[0;32mint\x1B[m\n");
    exit(EXIT_FAILURE);
  }

  return n;
}

int _readFileBool(int8_t* file) {
  FILE* f = (FILE*) file;

  int n;
  int r = fscanf(f, "%d", &n);

  if (r == EOF)
  {
    printf ("\x1B[0;31mError:\x1B[m End of file reached while reading a file\n");
    exit(EXIT_FAILURE);
  }
  if (r == 0)
  {
    printf ("\x1B[0;31mError:\x1B[m The value read from file is not of type \x1B[0;32mboolean\x1B[m\n");
    exit(EXIT_FAILURE);
  }

  if (n != 0 && n != 1)
  {
    printf ("\x1B[0;31mError:\x1B[m The value read from file is not of type \x1B[0;32mboolean\x1B[m\n");
    exit(EXIT_FAILURE);
  }

  return n;
}

char _readFileChar(int8_t* file) {
  FILE* f = (FILE*) file;
  char n;
  int r = fscanf(f, "%c", &n);

  if (r == EOF)
  {
    printf ("\x1B[0;31mError:\x1B[m End of file reached while reading a file\n");
    exit(EXIT_FAILURE);
  }
  if (r == 0)
  {
    printf ("\x1B[0;31mError:\x1B[m The value read from file is not of type \x1B[0;32mchar\x1B[m\n");
    exit(EXIT_FAILURE);
  }

  return n;
}

double _readFileDouble(int8_t* file) {
  FILE* f = (FILE*) file;
  double n;
  int r = fscanf(f, "%lf", &n);

  if (r == EOF)
  {
    printf ("\x1B[0;31mError:\x1B[m End of file reached while reading a file\n");
    exit(EXIT_FAILURE);
  }
  if (r == 0)
  {
    printf ("\x1B[0;31mError:\x1B[m The value read from file is not of type \x1B[0;32mfloat\x1B[m\n");
    exit(EXIT_FAILURE);
  }

  return n;
}

int _readIntStd () {
  int  n;
  char c;

  scanf("%d%c", &n, &c);
  return n;
}

int _readBoolStd () {
  int  n;
  char c;

  scanf("%d%c", &n, &c);
  if (n != 0 && n != 1)
  {
    printf ("\x1B[0;31mError:\x1B[m The value read from file is not of type \x1B[0;32mboolean\x1B[m\n");
    exit(EXIT_FAILURE);
  }
  return n;
}

char _readCharStd () {
  char n;
  char c;

  scanf("%c%c", &n, &c);

  return n;
}


double _readDoubleStd () {
  double n;
  char   c;

  scanf("%lf%c", &n, &c);
  return n;
}


void _writeInt(int x) {
  printf("%d", x);
}


void _writeDouble(double x) {
  printf("%f", x);
}


void _writeBool(int x) {
  if (x == 0)
    printf("false");
  else
    printf("true");
}


void _writeChar(int x) {
  setlocale(LC_CTYPE, "");

  printf("%lc", x);
}

void _writePointer(int8_t* x) {

  printf("%p", x);
}

void _writeString(char *x) {
  int i=0;
  setlocale(LC_CTYPE, "");

  printf ("%s", x);
}


void _ln() {
  printf("\n");
}


int _randInt() {
  return rand();
}

double _randFloat(){
  return (double)rand()/(double)(RAND_MAX);
}

char _randChar(){
  return (char)rand();
}

int _randBool(){
  return rand()%2;
}


int _max(int x, int y) {
  return x > y ? x : y;
}


double _maxF(double x, double y) {
  return x > y ? x : y;
}


int _min(int x, int y) {
  return x < y ? x : y;
}


double _minF(double x, double y) {
  return x < y ? x : y;
}

void _copyArray(int size, int8_t* source, int8_t* dest, int sizeT){
  for (int i = 0; i < size*sizeT; ++i)
    *(dest + i) = *(source + i);
}

typedef enum
  { A_IF
  , A_MANUAL
  , A_POST
  , A_ASSERT
  , A_INVARIANT
  , A_NONDECREASING_BOUND
  , A_NEGATIVE_BOUND
  , A_DIVISION_BY_ZERO
  , A_OVERFLOW
  , A_UNDERFLOW
  , A_EMPTY_RANGE
  , A_NULL_POINTER_ACCESS
  , A_REPRESENTATION_INVARIANT
  , A_NEGATIVE_INDEX
  , A_OUT_OF_BOUNDS_INDEX
  , A_BAD_ARRAY_ARG
  , A_NEGATIVE_ROOT
  , A_NEGATIVE_EXPONENT
  , A_BAD_ABSTRACT_COUPLE
  , A_COUPINVARIANT
  , A_ABSTRACT_POST
  } abort_t;

void _abort (abort_t reason, int line, int column) {
  printf ("\x1B[0;31mABORT:\x1B[m at line %d, column %d", line, column);
  switch (reason) {
    case A_IF:
      printf (":\n\tno true branch found in conditional.\n"); break;
    case A_MANUAL:
      printf (".\n"); break;
    case A_POST:
      printf (":\n\tthe postcondition was falsified.\n"); break;
    case A_ASSERT:
      printf (":\n\tthe assertion was falsified.\n"); break;
    case A_INVARIANT:
      printf (":\n\tthe invariant was falsified.\n"); break;
    case A_NONDECREASING_BOUND:
      printf (":\n\tthe bound didn't decrease.\n"); break;
    case A_NEGATIVE_BOUND:
      printf (":\n\tthe bound became negative.\n"); break;
    case A_DIVISION_BY_ZERO:
      printf (":\n\ta division by zero was attempted.\n"); break;
    case A_OVERFLOW:
      printf (":\n\ta value overflowed.\n"); break;
    case A_UNDERFLOW:
      printf (":\n\ta value underflowed.\n"); break;
    case A_EMPTY_RANGE:
      printf (":\n\tthe quantification range was empty.\n"); break;
    case A_NULL_POINTER_ACCESS:
      printf (":\n\ta null pointer was dereferenced.\n"); break;
    case A_REPRESENTATION_INVARIANT:
      printf (":\n\tthe representation invariant was falsified.\n"); break;
    case A_NEGATIVE_INDEX:
      printf (":\n\ta negative index was used to access an array.\n"); break;
    case A_OUT_OF_BOUNDS_INDEX:
      printf (":\n\tout of bounds index in access to array.\n"); break;
    case A_BAD_ARRAY_ARG:
      printf (":\n\tbad array argument, size mismatch.\n"); break;
    case A_NEGATIVE_ROOT:
      printf (":\n\tattempted to take the square root of a negative value.\n"); break;
    case A_NEGATIVE_EXPONENT:
      printf (":\n\tattempted to raise a number to a negative exponent.\n"); break;
    case A_BAD_ABSTRACT_COUPLE:
      printf (":\n\tthe abstract precondition was falsified.\n\tThe procedure doesn't implement the abstract type.\n"); break;
    case A_COUPINVARIANT:
      printf (":\n\tthe coupling invariant was falsified.\n"); break;
    case A_ABSTRACT_POST:
      printf (":\n\tthe abstract postcondition was falsified.\n"); break;
    default:
      printf (":\n\tunknown reason <%d>.\n", reason); break;
  }
  _freeTrashCollector();
  exit (EXIT_FAILURE);
}

typedef enum
  { W_MANUAL
  , W_PRE
  , W_POST
  , W_INVARIANT
  , W_REPINVARIANT
  , W_COUPINVARIANT
  } warning_t;

void _warn (warning_t reason, int line, int column) {
  printf ("\x1B[0;35mWARNING:\x1B[m at line %d, column %d", line, column);
  switch (reason) {
    case W_MANUAL:
      printf (".\n"); break;
    case W_PRE:
      printf (":\n\tthe precondition was falsified.\n"); break;
    case W_POST:
      printf (":\n\tthe postcondition was falsified.\n"); break;
    case W_INVARIANT:
      printf (":\n\tthe invariant was falsified.\n"); break;
    case W_REPINVARIANT:
      printf (":\n\tthe representation invariant was falsified.\n"); break;
    case W_COUPINVARIANT:
      printf (":\n\tthe coupling invariant was falsified.\n"); break;
    default:
      printf (":\n\tunknown reason.\n"); break;
  }
}

int _abs_i (int x, int line, int column) {
  if (x < 0){
    if (x == INT_MIN)
      _abort (A_OVERFLOW, line, column);
    return (-x);
  } else {
    return x;
  }
}

double _abs_f (double x) {
  return x < 0 ? (-x) : x;
}

int _sqrt_i (int x, int line, int column) {
  if (x < 0)
    _abort (A_NEGATIVE_ROOT, line, column);
  return floor(sqrt(x));
}

double _sqrt_f (double x, int line, int column) {
  if (x < 0)
    _abort (A_NEGATIVE_ROOT, line, column);
  return sqrt(x);
}


int _powInt (int x, int y, int line, int column) {
  if (y < 0)
    _abort (A_NEGATIVE_EXPONENT, line, column);
  else if (y == 0)
    return 1;
  else if (y % 2 == 1) {
    int tmp;
    if (__builtin_smul_overflow(x, _powInt (x, y-1, line, column), &tmp))
      // overflow
      _abort (A_OVERFLOW, line, column);
    // all ok
    return tmp;
  } else {
    int tmp = _powInt (x, y / 2, line, column);
    int tmp2;

    if (__builtin_smul_overflow(tmp, tmp, &tmp2))
      // overflow
      _abort (A_OVERFLOW, line, column);
    // all ok
    return tmp2;
  }
  return 0;
}


int _float2int (double x, int line, int column) {
  if (-2147483648.49 > x || x > 2147483647.49)
    _abort (A_OVERFLOW, line, column);
  return (x >= 0 ? (int)(x+0.5) : (int)(x-0.5));
}

int _char2int (char x) {
  return (int)(x);
}

char _float2char (double x, int line, int column) {
  if (0.0 > x || x > 255.49)
    _abort (A_OVERFLOW, line, column);
  return (char)(x+0.5);
}

char _int2char (int x, int line, int column) {
  if (0 > x || x > 255)
    _abort (A_OVERFLOW, line, column);
  return (char)x;
}

double _char2float (char x) {
  return (double)(x);
}

double _int2float (int x) {
  return (double)(x);
}


int _traceInt (int x) {
  printf("TRACE: %i\n", x);
  return x;
}
double _traceFloat (double x) {
  printf("TRACE: %f\n", x);
  return x;
}
char _traceChar (char x) {
  printf("TRACE: %c\n", x);
  return x;
}
int _traceBool (int x) {
  printf("TRACE: %s\n", x ? "true" : "false");
  return x;
}
int _traceStringInt (char* x, int y) {
  printf("TRACE: (%s, %i)\n", x, y);
  return y;
}
double _traceStringFloat (char* x, double y) {
  printf("TRACE: (%s, %f)\n", x, y);
  return y;
}
char _traceStringChar (char* x, char y) {
  printf("TRACE: (%s, %c)\n", x, y);
  return y;
}
int _traceStringBool (char* x, int y) {
  printf("TRACE: (%s, %s)\n", x, y ? "true" : "false");
  return y;
}
