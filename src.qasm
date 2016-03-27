// TI on-calc compiler





///// GET SOURCE PRGM DATA /////

/// look up program
ld hl,@prgmB_name
bcall _Mov9ToOP1
bcall _ChkFindSym

/// return if not found
jr nc,@was_found
ld a,Lquestion  // '?'
bcall _PutC
ret

@was_found
/// get end of program into bc & init hl as ptr to compiled code buf
ex de,hl
ld c,(hl) : inc hl : ld b,(hl) : inc hl
ld d,h : ld e,l
add hl,bc
ld b,h : ld c,l
ld hl,appBackUpScreen  // 768 bytes available

/// write 2-byte tasmCmp token
ld (hl),t2ByteTok : inc hl
ld (hl),tasmCmp : inc hl


///// READ AND COMPILE SOURCE /////

@nextParse
/// get next byte into a
xor a    // set a to 0 - no syntax error if EOF
call @getNextByte

/// token "Disp " -> bcall _NewLine
cp tDisp
jr nz,@tok_End
ld (hl),$EF : inc hl
ld (hl),$2E : inc hl
ld (hl),$45 : inc hl
jp @nextParse

@tok_End
/// token "End" -> ret
cp tEnd
jr nz,@tok_dot
ld (hl),$C9 : inc hl
jp @nextParse

@tok_dot
/// token "."   (in .[#]->[reg])  -> ld [reg],[#]
cp tDecPt
jr nz,@tok_newline
call @getNextByte
call @getImmediate
//push de
ld de,(saveSScreen)
cp tStore
jp nz,@throwSyntaxErr
call @getRegCode
//...
jp @nextParse

@tok_newline
/// token [newline] or ":"
cp tEnter
jp z,@nextParse
cp tColon
jp z,@nextParse

/// invalid token
jp @throwSyntaxErr


///// WRITE FINAL PROGRAM /////
@writeFinalPrgm

/// search for the program & delete it if it exists
push hl
ld hl,@prgmC_name
bcall _Mov9ToOP1
bcall _ChkFindSym
jr c,@writeFinalPrgm_skip
bcall _DelVarArc

@writeFinalPrgm_skip
/// get the new program's length (hl-appBackUpScreen) into hl & save it
ld bc,$678E  // $FFFF-appBackUpScreen
pop hl : add hl,bc : push hl

/// create program and copy data into it
bcall _CreateProtProg
inc de : inc de
pop bc    // loads the saved value of hl
ld hl,appBackUpScreen
ldir


///// END /////
ret





///// DATA / ROUTINES /////

@prgmB_name
.db ProgObj tB 0  // prgmB
@prgmC_name
.db ProtProgObj tC 0  // prgmC (protected)

@throwSyntaxErr // routine: throw ERR:SYNTAX (ends program)
ld a,E_Syntax
bjump _JError

@getNextByte // routine: get next byte into a (and check if EOF)
push af
// check for EOF (de==bc)
ld a,e : cp c
jr nz,@getNextByte_noEOF
ld a,d : cp b
jr nz,@getNextByte_noEOF
//// if EOF...
pop af
inc sp : inc sp // pops the return addr. so we can jump out
// throw syntax error if a!=0, otherwise write program
or a            // same as cp 0
jp z,@writeFinalPrgm
jp @throwSyntaxErr
//// if not EOF...
@getNextByte_noEOF
pop af
ld a,(de) : inc de
ret

@getImmediate // routine: read an immediate value into de (de -> saveSScreen)
push hl
ld hl,0
@getImmediate_loop
sub t0
cp 9
jr nc,@getImmediate_loopEnd
push de
ld d,h : ld e,l
add hl,hl : add hl,hl : add hl,de : add hl,hl
pop de
add a,l : ld l,a
adc a,h : sub l : ld h,a
call @getNextByte
jr @getImmediate_loop
@getImmediate_loopEnd
add a,$30
ex de,hl
ld (saveSScreen),hl
pop hl
ret

@getRegCode // routine: read a register and return its "code" in a
call @getNextByte
sub tB
cp 6     //  -
jr nz,+2 //  | "H"
ld a,4   //  -
cp 10        //  -
jr nz,+2     //  | "L"
ld a,5       //  -
cp 17                //  -
jr nz,@getRegCode_aSP//  |
call @getNextByte    //  |
cp tS                //  | "SP"
jp nz,@throwSyntaxErr//  |
ld a,3               //  |
ret                  //  -
@getRegCode_aSP
//...
ret
