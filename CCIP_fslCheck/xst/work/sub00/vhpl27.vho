     � H  ��        L⏹         �         :   rtl  � �)        A  Y  6�  R	  ma  ��  �  �i  �� 	�  �  �y  �a  �I  �1  � q A 0� O� kI �� �� �9 �y � �� � q :Q A )  � "� &� B! I� Q� Y� aa i1 |� �A �� �� ֑ � A � <! S� r� �) �� �� �i .Q A� � � E1 	'� ˉ a� �I  Z   7  A  :�  U�  qI  ��  ��  �Q  ީ �  � Y ) 4� S� o1 �q �� �! �a �� �� � Y 6i *� F	 M� U� ]y eI m �� �) �i �� �y �� )  � @	 Wy v� � �� �� �9 *i E� �) �1 I 	+� �q ]� �1       
 =� AI 	#� ǡ �a � �� �� �q �A  �       �  �     �)     v �          A     @     A     :   NO_OF_BYTES_LIMIT  A  �     !   _  Y     �  q  �     @     '     ' Q3     #)  *�      .�     @      '     v  �\     '      :�     s   00000110  �\  :�     :   WREN  :�  �    �� !   b  6�     .�  2�  �     @     Bi     ' Q3     >�  FQ      J9     @      Bi     v  �\     Bi      U�     s   00000100  �\  U�     :   WRDI  U�  �    �� !   c  R	     J9  N!  �     @     ]�     ' Q3     Y�  a�      e�     @      ]�     v  �\     ]�      qI     s   00000101  �\  qI     :   RDSR  qI  �    �� !   d  ma     e�  iy  �     @     y     ' Q3     u1  }      ��     @      y     v  �\     y      ��     s   00000001  �\  ��     :   WRSR  ��  �    �i !   e  ��     ��  ��  �     @     �q     ' Q3     ��  �Y      �A     @      �q     v  �\     �q      ��     s   00000011  �\  ��     :   RD  ��  �    �9 !   f  �     �A  �)  �     @     ��     ' Q3     ��  ��      ��     @      ��     v  �\     ��      �Q     s   00000010  �\  �Q     :   WR  �Q  �    �Q !   g  �i     ��  ��  �     @     �!     ' Q3     �9  �	      ��     @      �!     v  �\     �!      ީ     s   11000111  �\  ީ     :   BE  ީ  �     !   h  ��     ��  ��  �     -   
waitforirq  �      �     -   getbyte  �     �     -   setrevision  �     �     -   setnoofbytes  �     �     -   checkinstruction  �     �     -   runop  �     �     ,   k  � 	�  �      	�     �  �y  �a  �I  �1  �             .  �� �     |   k 	� �  �     :   APP_STATE_TYPE �  �     v 	�         Y     :   appState Y  �     p   l q    �  �      �     :   nextAppState )  �     p   m A    �  �      �     @    $�     ' Q3    ! (�     ,�     @     $�     v  �\    $�     4�     :   currentByte 4�  �     p   n 0�    ,� <i      �     
    $�  � <i      ,�    8� 4�     @    D9     ' Q3    @Q H!     L	     @     D9     v  �\    D9     S�     :   appDataAddr_i S�  �     p   o O�    L	 [�      �     
    D9  � [�      L	    W� S�     @     cy      Q3    _� ga     o1     @    cy     :   rdOffset o1  �     p   p kI    cy _�      �     @     w      Q3    s ��     �q     S  #     Y ~�        �� @    z�     @  � w     @  �         :   	noOfBytes �q  �     p   q ��    w s      �     @    �A     ' Q3    �Y �)     �     @     �A     v  �\    �A     ��     :   revNo ��  �     p   r ��    � ��      �     
    �A  � ��      �    �� ��     @    ��     ' Q3    �� �i     �Q     @     ��     v  �\    ��     �!     :   sizeMsb �!  �     p   s �9    �Q ��      �     
    ��  � ��      �Q    �	 �!     @    ��     ' Q3    �� ة     ܑ     @     ��     v  �\    ��     �a     :   size �a  �     p   t �y    ܑ �1      �     
    ��  � �1      ܑ    �I �a     v  ��         ��     :   rwn ��  �     p   u �    �  �      �     :   rdInProgess ��  �     p   v ��    �  �      �     :   startOp �  �     p   w �    �  �      �     :   appDataReq_i Y  �     p   x q    �  �      �     -   waitforstartop *�      �     -   
setclkhigh *�     �     -   	setclklow *�     �     -   setcslow *�     �     -   	setcshigh *�     �     -   delayoneperiod *�     �     ,   { A :Q  �      :Q    A )  � "� &�             . .� 6i     |   { :Q 2�  �     :   PHY_STATE_TYPE 6i  �     v :Q         F	     :   phyState F	  �     p   | B!    >9 A      �     :   
phyState_d M�  �     p   } I�    >9 A      �     :   nextPhyState U�  �     p   ~ Q�    >9 A      �     :   
getNewByte ]y  �     p    Y�    �  �      �     :   opDone eI  �     p   � aa    �  �      �     :   spiPhyInProgress m  �     p   � i1    �  �      �     @     t�      Q3    q x�     ��     @    t�     :   shiftOutCnt ��  �     p   � |�    t� q      �     @     �q      Q3    �� �Y     �)     @    �q     :   
shiftInCnt �)  �     p   � �A    �q ��      �     @     ��      Q3    � ��     �i     S  #     Y ��        �� @    ��     @  � ��     @  �         :   byteCnt �i  �     p   � ��    �� �      �     @    �9     ' Q3    �Q �!     �	     @     �9     v  �\    �9     ��     :   shiftOutReg ��  �     p   � ��    �	 ҩ      �     
    �9  � ҩ      �	    �� ��     :   updShiftOutReg �y  �     p   � ֑    �  �      �     @    �I     ' Q3    �a �1     �     @     �I     v  �\    �I     ��     :   spiDataAddr_i ��  �     p   � �    � ��      �     
    �I  � ��      �    �� ��     @    �     ' Q3    �� q     	Y     @     �     v  �\    �     )     :   spiDataAddr_d )  �     p   � A    	Y �      �     
    �  � �      	Y     )     :   	validMiso  �  �     p   � �    �  �      �     @     (�      Q3    $� 4Q     @	     S  #     Y 0i        89 @    ,�     @  � (�     @  �         :   noOfBytesTransmitted @	  �     p   � <!    (� $�      �     @    G�     ' Q3    C� K�     O�     @     G�     v  �\    G�     Wy     :   misoMetaReg Wy  �     p   � S�    O� _I      �     
    G�  � _I      O�    [a Wy     @    g     ' Q3    c1 k     n�     @     g     v  �\    g     v�     :   
shiftInReg v�  �     p   � r�    n� ~�      �     
    g  � ~�      n�    z� v�     @     �Y      Q3    �q �A     �     @    �Y     :   shiftInCnt_d �  �     p   � �)    �Y �q      �     :   spiClkEn ��  �    �� p   � ��    �  �      �     @    ��      Q3    ��  *�     ��     :   clkCnt ��  �     p   � ��    �� ��      �     :   SIGIS �9  �     v ��         �9        � �i �Q  �     s   CLK �� ��        � �i ��     � �i �! �	 ��                         :	 =�     S .Q     6�  \ 6!     @    Б     � ̩         �y     o   �     Б ��         6!     �  \         �I     o   �     �a ��         6!       ��     >�  �[ �     S .Q     >�  D �     S ��    �1 � 29     S w�    ��  *� �     @    �     � ��         ��     o   �     � ��         �     �  D         �q     o   �     �� ��         �     S �c    �� A )     @    Y     � Y              o   �     ) ��         �     �  \         �     o   �     � ��         �     r          �;     � "�     r         ��    �� �q "�     <   �        � � 29     v  ��         *i     U     .Q     FT  FT  �� &�  �     T   = *i  �     r         �    "� :	     r         ��    �y �I :	     <   �        6! 29 ��     a   � A� ��     >�  6�  �     :   gen2Mhz E�  �     E   � A� =�  �                         =a AI     S .Q     6�  \ 9y     �  �         Ua     o   �     Qy q         9y     �  �         ]1     o   �     YI A         9y     V         e     
    x�  \ h�      L	    e l�     � h�         |q     @     x�     @    x�     ' Q3    t� p�     e     o   �     l� O�         9y     @     �A     � �Y         �)     o   �     �A kI         9y     �  \         ��     o   �     � �         9y     @     ��     � ��         ��     o   �     �� ��         9y     �  \         ��     o   �     �� �         9y     V         �Q     
    ��  \ �9      ,�    �Q �!     � �9         ��     @     ��     @    ��     ' Q3    �� �	     �Q     o   �     �! 0�         9y     �  \         ʑ     o   �     Ʃ ֑         9y     �  \         �a     o   �     �y ��         9y     @     �1     � �I         �     o   �     �1 <!         9y     V         ��     
    �q  \ ��      �Q    �� ��     � ��         �Y     @     �q     @    �q     ' Q3    �� �     ��     o   �     �� �9         9y     V         )     
    �  \ 	      ܑ    ) �     � 	         �     @     �     @    �     ' Q3    � �     )     o   �     � �y         9y     V         $i     
    7�  \ (Q      �    $i ,9     � (Q         ;�     @     7�     @    7�     ' Q3    4	 0!     $i     o   �     ,9 ��         9y       ��     >�  �[ G�     S .Q     >�  D G�     S ��    ?� C� 5�     �  \         Oa     o   �     Ky ֑         5�     {  J=    �y W1     S �e    _ [     � W1         b�     Y    �� SI         o   �     [ ��         5�     S w�    <! kI ��     � �         n�     o   �     j� ��         ��     S �    q  � ��     �  \         zY     o   �     vq ��         ��     v  ��         �)     U     �    	� 	�  �� ~A  �     T   = �)  �     r         r�    zY ��     � ��         ��     o   �     �� ��         ��     r          �;    �� ��     r         f�    n� ��     <   �        �� �� �� 5�        �        � Y �Q �� �	 ! 1� q 5�     V         �9     
    ��  \ �!      L	    �9 �	     � �!         ��     @     ��     @    ��     ' Q3    �� ��     �9     o   �     �	 O�         �     S .Q     FR  D ��     �  �y         �a     o   �     �y q         ��     �  �a         �1     o   �     �I A         ��     �  �         �     o   �     � q         ��     r          �;    � �     r         đ    �a �1 �     <   �        �� �� �          � �     r         �    �� � �i     S .Q    ��  D &9     � A         �A     o   �     �Y q         &9     �  mb              o   �     �) 0�         "Q     � A         
�     o   �     � q         "Q     S  �.    � � �     � �         i     Y     �� O�         Y     �^  D         o   �     � O�         "Q     r          �;     
� i *!     r         �q    �A *!     <   �        &9 "Q Y     S �    A  �1 5�     S �    A  � 5�     S �{    .	 1� MI     �  D         =�     o   �     9� ֑         MI     �  \         Ey     o   �     A� ֑         Ia     r          �;    Ey Q1     r         5�    =� Q1     <   �        MI Ia Y          �y Y     r         U    *! Q1 �i     �  �y         `�     o   �     \� q         �Q     �  �I         h�     o   �     d� A         �Q     @    pq     ' Q3    l� tY     xA     @    pq     q    0� pq |)     � xA         �     o   �     |) ��         �Q     @    ��     ' Q3    �� ��     ��     @     ��     q    0� �� ��     � ��         ��     o   �     �� �9         �Q          �a �Q     r         �i    `� h� � �� �i     �  �y         �!     o       �9 q         ��     �  �1         ��     o       �	 A         ��     S �    �9 �y �a     @    ��     ' Q3    �� ��     �y     @     ��     q    0� �� ��     � ��         �     v  �\         �1     U     �     �\  �\  �\ �I  �     T   & �1  �     o       �a �y         ��          �I ��     r         ��    �! �� � �i     �  �         �     o  	     � q         �	               �  9 jq �� 0� �	     �  D         �Y     o       �q �         �     @    �)     � �A         �     o       �) kI         �          ma �     r          �    �Y � �          6�  R	  ��  �i  9     �  \         �     o       � �          9     @    i     � �         Q     o       i kI          9     r         �    � Q �     �  D         (	     o       $! �         jq     S .Q     N"  \ ^�     @    3�     � /�         7�     o       3� kI         ^�     S .Q     N"  D K1     @    Ca     � ?y         GI     o       Ca kI         K1     r         ;�    GI b�     @     S     � O         V�     o        S kI         Z�     r          �;    V� b�     r         +�    7� b�     <          ^� K1 Z� jq          � jq     r         f�    (	 b� �     V         ��     � �         v)     o  $     rA �         ��     � kI         }�     o  %     z kI         ��         nY ��     r         ��    v) }� �     s   00000101  �\         s   00000110  �\         s   00000100  �\         s   00000001  �\         s   00000010  �\         s   00000011  �\              �1 �	     r         �!    � � �i     S .Q    aa  D i     �  �         ��     o  +     �� q         i     @     ��     � ��         �y     o  ,     �� <!         i     S .Q    Y�  D �     S �c    <! �1 �     @    �I     � �I         �     o  .     � <!         �     �  �y         ��     o  /     �� q         �     �  �         ߡ     o  0     ۹ A         �     r         �a    � �� ߡ Q     S .Q    i1  D ��     �  �         �A     o  2     �Y q         ��     �  \         �     o  3     �) �         ��     r         �q    �A � Q     �  �         �     o  5     �� q         �     �  D         
�     o  6     � �         �     r          �;    � 
� Q     r         ��    �� �y Q     <  *        i � �� � !          � !     r         9    Q �i     V         -�     �  �         )�     o  :     %� q         1�         "	 1�     r         -�    )� �i     r         G�    Oa b� �� �i =a     r         M�    Ua ]1 |q �) �� �� �� �� ʑ �a � �Y � ;� =a     <   �        9y 5� I�     a   � E1 I�     >�  6�  �     :   	spiApplic I  �     E   � E1 AI  �                         	� 	#�     S .Q     6�  \ 		     �  \         X�     o  F     T� q         		       ��     >�  �[ dq     S .Q     >�  D dq     S ��    \� `� 	!     �  \         lA     o  H     hY q         	!     S .Q    i1  D 	Q     S 
k    <! w� 	�     S  #    �� {� t     @    w�     @    ��     ' Q3    � ��     ��     @     ��     q    O� �� �i     S (�    �) � ��     s   11  �\ �i     S �\    �	 �!     � �9         ��     Y    �� ��         o  N     �! q         ��     @    ��     ' Q3    �� ��     ��     @     ��     q    O� �� �y     S (�    չ ١ �1     s   01  �\ �y     S .Q    �  \ �1     S ��    �y �I ݉     S �\    �� �     � �         ��     Y    �� ��         o  P     � q         ݉     Y    � ��         Y     � �a         r         �1    �� ��     �  \         �Y     o  R     �q q         �A     r          �;    �Y ��     Y    � ��         Y     � �Q         r         �i    �� ��     <  L        �� ݉ �A 	�     �  \         	 �     o  U     �� q         	�     r          �;    	 � 	i     r         t    �� 	i     <  J        	� 	� 	Q     r         p)    	i 	9     <  I        	Q 	!     r         dq    lA 	9 	�     r         P�    X� 	�     <  E        		 	! M     a  C 	'� M     >�  6�  �     :   appInterface 	+�  �     E  C 	'� 	#�  �                         ù ǡ     S .Q     6�  \ ��     �  \         	;I     o  d     	7a aa         ��     �  \         	C     o  e     	?1  �         ��     �  D         	J�     o  f     	G  �b         ��     �  D         	R�     o  g     	N�  �2         ��     @     	Z�     � 	V�         	^q     o  h     	Z� |�         ��     @     	fA     � 	bY         	j)     o  i     	fA �A         ��     @     	q�     � 	n         	u�     o  j     	q� ��         ��     �  \         	}�     o  k     	y� Y�         ��     �  \         	��     o  l     	�� i1         ��     � A         	�Q     o  m     	�i B!         ��     � A         	�!     o  n     	�9 I�         ��     � A         	��     o  o     	�	 Q�         ��       ��     >�  �[ 	��     S .Q     >�  D 	��     S ��    	�� 	�� ��     � B!         	�y     o  q     	�� I�         ��     �  \         	�I     o  r     	�a Y�         ��     �  \         	�     o  s     	�1 aa         ��     S .Q    ��  D �       w        

Q 'y N� u� �� �y �1 B! �     �  \         	Ϲ     o  z     	��  �         

Q     �  \         	׉     o  {     	ӡ i1         

Q     �  \         	�Y     o  |     	�q aa         

Q     S .Q    �  D 	��     � �         	�     o  ~     	�) B!         	��     �  D         	��     o       	�� i1         	��     � ��         	��     o  �     	�� ��         	��     r         	�A    	� 	�� 	�� 
�     <  }        	�� 

Q         A 

Q     r         
i    	Ϲ 	׉ 	�Y 
� 	��     �  D         
!     o  �     
9  �2         'y     S .Q    ��  \ �     S w�    |� 
� 
�9     @    
�     @     
%�     � 
!�         
)�     o  �     
%� |�         
�9     S w�    �� 
1a 
h     @     
-y     � &�         
91     o  �     
5I B!         
h     � "�         
A     o  �     
= Q�         
h     �  D         
H�     o  �     
D� Y�         
d)     S  #    �� 
P� 
T�     @    
L�     � 
L�         
Xq     o  �     
T� ��         
d)     �          
`A     o  �     
\Y B!         
d)     r          �;    
H� 
Xq 
`A 
k�     r         
-y    
91 
A 
k�     <  �        
h 
d) 
�9     �          
s�     o  �     
o� B!         
�Q     S �c    |� 
{� 
�     @    
w�     � 
w�         
�i     o  �     
� |�         
�Q     r          �;    
s� 
�i 
�!     r         
�    
)� 
k� 
�!     <  �        
�9 
�Q �     S w�    �A 
�� 	     @    
�	     S w�    �� 
�� 
��     @     
��     � &�         
��     o  �     
�� B!         
��     � "�         
�a     o  �     
�y Q�         
��     @     
�1     � 
�I         
�     o  �     
�1 �A         
��     �  D         
��     o  �     
� Y�         
��     S  #    �� 
ɹ 
͡     @    
��     � 
��         
щ     o  �     
͡ ��         
��     �          
�Y     o  �     
�q B!         
��     @    
�)     � 
�A         
�     o  �     
�) �A         
��     r          �;    
�� 
щ 
�Y 
� 
��     r         
��    
�� 
�a 
� 
��     <  �        
�� 
�� 	     �          
��     o  �     
�� B!         !     S �c    �A  i Q     @    
��     � 
��         9     o  �     Q �A         !     r          �;    
�� 9 �     r         
�	    
�� �     <  �        	 ! �     r          �;    � �     r         
	    
�! �     <  �        � � 'y         ) 'y     r         #�    
! � 	��     �  \         /I     o  �     +a  �2         N�     @    7     >    �� 31 ;     � 7         >�     o  �     ;  �         N�     � )         F�     o  �     B� B!         N�          N�     r         J�    /I >� F� 	��     �  D         VY     o  �     Rq  �b         u�     �  D         ^)     o  �     ZA aa         u�     �  \         e�     o  �     b i1         u�     � A         m�     o  �     i� B!         u�         "� u�     r         q�    VY ^) e� m� 	��     �  \         }i     o  �     y�  �b         ��     � &�         �9     o  �     �Q B!         ��     �          �	     o  �     �! Q�         ��         � ��     r         ��    }i �9 �	 	��     � Q�         ��     o  �     �� B!         �y         &� �y     r         ��    �� 	��     V         �I         �a �1     r         �I     	��     r         	�    	�� �     <  u        � ��     r         	��    	�y 	�I 	� � ù     r         	3y    	;I 	C 	J� 	R� 	^q 	j) 	u� 	}� 	�� 	�Q 	�! 	�� ù     <  c        �� �� 	/�     a  a ˉ 	/�     >�  6�  �     :   spiPhysical �q  �     E  a ˉ ǡ  �                         �y �a     S .Q     6�  \ ��     V         �     
    �  \ ��      n�    � ��     � ��         ��     @     �     @    �     ' Q3    � ��     �     o  �     �� r�         ��     V         �Q     
    �  \ 9      �	    �Q !     � 9         �     @     �     @    �     ' Q3    � 
	     �Q     o  �     ! ��         ��     V         �     
    1  \ !y       �*    � %a     � !y         5     @     1     @    1     ' Q3    -1 )I     �     o  �     %a  �         ��     V         <�     
    PY  \ @�      �    <� D�     � @�         TA     @     PY     @    PY     ' Q3    Lq H�     <�     o  �     D� �         ��     V         \     
    o�  \ _�      	Y    \ c�     � _�         s�     @     o�     @    o�     ' Q3    k� g�     \     o  �     c� A         ��     �  \         {Q     o  �     wi  �R         ��     �  \         �!     o  �     9  �"         ��     �  \         ��     o  �     �	 �         ��     V         ��     
    �I  \ ��      O�    �� ��     � ��         �1     @     �I     @    �I     ' Q3    �a �y     ��     o  �     �� S�         ��     @     �     � �         ��     o  �     � �)         ��       ��     >�  �[ ��     S .Q     >�  D ��     S ��    �� �� ��     �  \         �q     o  �     ŉ  �R         ��     �  \         �A     o  �     �Y  �"         ��     � �A         �     o  �     �) �)         ��     � �         ��     o  �     �� A         ��     @     �     >    S� �� ��     �  ��         ��     o  �     � �         ��     @    �Q     ' Q3    �i �9      !     @    �Q     q    S� �Q �     @    �     ' Q3    	 �     �     @     �     q    S� � �     � �         �     o  �     �  !         ��     S .Q    ֑  D i�     � 0�         #I     o  �     a ��         i�     S a�    B!  /     S a�    I� ) /     S ��    '1 + e�     @    6�     ' Q3    2� :�     >�     @    6�     q    �� 6� V     @    Fq     ' Q3    B� JY     NA     @     Fq     q    �� Fq R)     � NA         V     o  �     R) >�         e�     v  ��         ]�     U     a�    :Q :Q  �� Y�  �     T   = ]�  �     r         /    V m�     r         y    #I m�     <  �        i� e� ��     S .Q    ��  D y9     S a�    B! ) y9     S ��    qi uQ �I     �  D         �	     o  �     }! �         �I     S a�    B! &� ��     �  \         ��     o  �     �� �         ��     r         ��    �� �1     � �         �y     o  �     �� �         �a     r          �;    �y �1     r         y9    �	 �1     <  �        �I �� �a ��     S .Q    �  D ��     S a�    B! ) ��     S a�    I�  ��     S ��    � �� {	     @     ��     >    r� �� �A     @    �q     >    S� �� �Y     � �q         �A     o       �Y ��         {	     @    �     ' Q3    �) ��     ��     @    �     q    r� � �Q     @    �     ' Q3    �� �     �     @     �     q    r� � �i     � �         �Q     o       �i ��         {	     S w�    �A �! �     @     �9     S w�    �A � �     @    �	     S �{    �9 �	 �     S w�    �) � �     @    	�     S ��    � 	� w!     � r�         a     o       y  �         w!     S  �.    % ) !1     � I         ,�     Y     �� �         Y     �^  D         o  	     !1 �         w!     �  D         4�     o  
     0�  �R         w!     S w�    <! �� oQ     �  D         @q     o       <�  �"         oQ     V         HA     
    [�  \ L)      �    HA P     � L)         _�     @     [�     @    [�     ' Q3    W� S�     HA     o       P �         oQ     �  \         g�     o       c�  �"         ki     r          �;    g� s9     r         8�    @q _� s9     <          oQ ki w!     r         �    a ,� 4� s9 ~�     r         ��    �A �Q ~�     <          {	 w! ��     r         �    ~� ��     <           �� ��     r         ��   	 �q �A � �� �� � m� �1 �� �y     r         �A   
 �� � 5 TA s� {Q �! �� �1 �� �y     <  �        �� �� �Y     a  � �I �Y     >�  6�  �     :   shift �1  �     E  � �I �a  �     � O�         �            �  ��              �     � q         ��            ��  ��              �     � A         ��            ��  ��              �     � aa         �q            ��  U�              �     � ��         �A            �Y  ��              �     %     �  �  ��     � �     �   W:/CCIP/spi_rtl_ea.vhd �)  �                spi   rtl   work      spi   rtl   work      spi       work      standard       std      std_logic_1164       IEEE      numeric_std       IEEE      std_logic_unsigned       IEEE