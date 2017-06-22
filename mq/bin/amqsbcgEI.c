/* @(#) samples/c/amqsbcg0.c, samples, p600, p600-201-061220 1.33.1.1 05/05/26 12:20:41 */
/**********************************************************************/
/*                                                                    */
/* Program name: AMQSBCG0                                             */
/*                                                                    */
/* Description : Sample program to read and output both the           */
/*                 message descriptor fields and the message content  */
/*                 of all the messages on a queue                     */
/* <N_OCO_COPYRIGHT>                                                  */
/* Licensed Materials - Property of IBM                               */
/*                                                                    */
/* 63H9336                                                            */
/* (c) Copyright IBM Corp. 1994, 2005 All Rights Reserved.            */
/*                                                                    */
/* US Government Users Restricted Rights - Use, duplication or        */
/* disclosure restricted by GSA ADP Schedule Contract with            */
/* IBM Corp.                                                          */
/* <NOC_COPYRIGHT>                                                    */
/*                                                                    */
/* Function    : This program is passed the name of a queue manager   */
/*               and a queue. It then reads each message from the     */
/*               queue and outputs the following to the stdout        */
/*                    -  Formatted message descriptor fields          */
/*                    -  Message data (dumped in hex and, where       */
/*                       possible, character format)                  */
/*                                                                    */
/* Parameters  : Queue Manager Name                                   */
/*               Queue Name                                           */
/*                                                                    */
/* Restriction : This program is currently restricted to printing     */
/*               the first 32767 characters of the message and will   */
/*               fail with reason 'truncated-msg' if a longer         */
/*               message is read                                      */
/*                                                                    */
/* Note:         To convert this program to read the messages         */
/*               destructively, rather than browsing, change          */
/*               GetMsgOpts and Open Options by commenting out        */
/*               two lines in the program. See lines marked @@@@.     */
/*                                                                    */
/**********************************************************************/
/*                                                                    */
/*                     Program logic                                  */
/*                     -------------                                  */
/*                                                                    */
/*    main (Last function in the code)                                */
/*    ----                                                            */
/*        Initialize the variables                                    */
/*        If correct parameters not passed                            */
/*          Report the error to the user                              */
/*          Terminate the program with return code 4                  */
/*        End-if                                                      */
/*        Connect to the queue manager                                */
/*        If the connect fails                                        */
/*          Report the error to the user                              */
/*          Terminate the program                                     */
/*        End-if                                                      */
/*        Open the queue                                              */
/*        If the open fails                                           */
/*          Report the error to the user                              */
/*          Terminate the program                                     */
/*        End-if                                                      */
/*        While compcode is ok                                        */
/*          Reset call variables                                      */
/*          Get a message                                             */
/*          If compcode not ok                                        */
/*            If reason not no-msg-available                          */
/*              print error message                                   */
/*            Else                                                    */
/*              print no more messages                                */
/*            End-if                                                  */
/*          Else                                                      */
/*            Call printMD                                            */
/*            Print the message length                                */
/*            Print each group of 16 bytes of the message as follows: */
/*            -Offset into message (in hex)                           */
/*            -Message content in hex                                 */
/*            -Printable message content ('.' if not printable)       */
/*            Pad the last line of the message to maintain format     */
/*          End-if                                                    */
/*        End-while                                                   */
/*        Close the queue                                             */
/*        If the close fails                                          */
/*          Report the error to the user                              */
/*          Terminate the program                                     */
/*        End-if                                                      */
/*        Disconnect from the queue manager                           */
/*        If the disconnect fails                                     */
/*          Report the error to the user                              */
/*        End-if                                                      */
/*        Return to calling program                                   */
/*                                                                    */
/*                                                                    */
/*    printMD                                                         */
/*    -------                                                         */
/*        For each field of the message descriptor                    */
/*         Print the field name and contents                          */
/*                                                                    */
/**********************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <ctype.h>
#include <locale.h>
#include <cmqc.h>

#define    CHARS_PER_LINE  16  /* Used in formatting the message */
#define    BUFFERLENGTH  4194304  /* Max length of message accepted */

/**********************************************************************/
/* Function name:    printMD                                          */
/*                                                                    */
/* Description:      Prints the name of each field in the message     */
/*                   descriptor together with it's contents in the    */
/*                   appropriate format viz:                          */
/*                   integers as a number (%d)                        */
/*                   binary fields as a series of hex digits (%02X)   */
/*                   character fields as characters (%s)              */
/*                                                                    */
/* Called by:        main                                             */
/*                                                                    */
/* Receives:         pointer to message descriptor structure          */
/*                                                                    */
/* Calls:            nothing                                          */
/*                                                                    */
/**********************************************************************/
void printMD(MQMD *MDin)
{
   int i;

   printf("\n****Message descriptor****\n");
   printf("\n  StrucId  : '%.4s'", MDin->StrucId);
   printf("  Version : %d", MDin->Version);
   printf("\n  Report   : %d", MDin->Report);
   printf("  MsgType : %d", MDin->MsgType);
   printf("\n  Expiry   : %d", MDin->Expiry);
   printf("  Feedback : %d", MDin->Feedback);
   printf("\n  Encoding : %d", MDin->Encoding);
   printf("  CodedCharSetId : %d", MDin->CodedCharSetId);
   printf("\n  Format : '%.*s'", MQ_FORMAT_LENGTH, MDin->Format);
   printf("\n  Priority : %d", MDin->Priority);
   printf("  Persistence : %d", MDin->Persistence);
   printf("\n  MsgId : X'");

   for (i = 0 ; i < MQ_MSG_ID_LENGTH ; i++)
     printf("%02X",MDin->MsgId[i] );

   printf("'");
   printf("\n  CorrelId : X'");

   for (i = 0 ; i < MQ_CORREL_ID_LENGTH ; i++)
     printf("%02X",MDin->CorrelId[i] );

   printf("'");
   printf("\n  BackoutCount : %d", MDin->BackoutCount);
   printf("\n  ReplyToQ       : '%.*s'", MQ_Q_NAME_LENGTH,
          MDin->ReplyToQ);
   printf("\n  ReplyToQMgr    : '%.*s'", MQ_Q_MGR_NAME_LENGTH,
          MDin->ReplyToQMgr);
   printf("\n  ** Identity Context");
   printf("\n  UserIdentifier : '%.*s'", MQ_USER_ID_LENGTH,
          MDin->UserIdentifier);
   printf("\n  AccountingToken : \n   X'");

   for (i = 0 ; i < MQ_ACCOUNTING_TOKEN_LENGTH ; i++)
     printf("%02X",MDin->AccountingToken[i] );

   printf("'");
   printf("\n  ApplIdentityData : '%.*s'", MQ_APPL_IDENTITY_DATA_LENGTH,
          MDin->ApplIdentityData);
   printf("\n  ** Origin Context");
   printf("\n  PutApplType    : '%d'", MDin->PutApplType);
   printf("\n  PutApplName    : '%.*s'", MQ_PUT_APPL_NAME_LENGTH,
          MDin->PutApplName);
   printf("\n  PutDate  : '%.*s'", MQ_PUT_DATE_LENGTH, MDin->PutDate);
   printf("    PutTime  : '%.*s'", MQ_PUT_TIME_LENGTH, MDin->PutTime);
   printf("\n  ApplOriginData : '%.*s'\n", MQ_APPL_ORIGIN_DATA_LENGTH,
          MDin->ApplOriginData);
   printf("\n  GroupId : X'");

   for (i = 0 ; i < MQ_GROUP_ID_LENGTH ; i++)
     printf("%02X",MDin->GroupId[i] );

   printf("'");
   printf("\n  MsgSeqNumber   : '%d'", MDin->MsgSeqNumber);
   printf("\n  Offset         : '%d'", MDin->Offset);
   printf("\n  MsgFlags       : '%d'", MDin->MsgFlags);
   printf("\n  OriginalLength : '%d'", MDin->OriginalLength);
}  /* end printMD */


/**********************************************************************/
/* Function name:    main                                             */
/*                                                                    */
/* Description:      Connects to the queue manager, opens the queue,  */
/*                   then gets each message from the queue in a loop  */
/*                   until an error occurs. The message descriptor    */
/*                   and message content are output to stdout for     */
/*                   each message. Any errors are output to stdout    */
/*                   and the program terminates.                      */
/*                                                                    */
/* Receives:         Two parameters - queue manager name              */
/*                                  - queue name                      */
/*                                                                    */
/* Calls:            printMD                                          */
/*                                                                    */
/**********************************************************************/
int  main(int argc, char *argv[] )
{
  /*                                                                  */
  /* variable declaration and initialisation                          */
  /*                                                                  */
  int i = 0;       /* loop counter                                    */
  int j = 0;       /* another loop counter                            */

  /* variables for MQCONN            ******/
  MQCHAR  QMmgrName[MQ_Q_MGR_NAME_LENGTH];
  MQHCONN Hconn = 0;
  MQLONG  CompCode,Reason,OpenCompCode;

  /* variables for MQOPEN            ******/
  MQCHAR  Queue[MQ_Q_NAME_LENGTH];
  MQOD    ObjDesc = { MQOD_DEFAULT };
  MQLONG  OpenOptions;
  MQHOBJ  Hobj = 0;

  /* variables for MQGET             ******/
  MQMD    MsgDesc = { MQMD_DEFAULT };
  PMQMD   pmdin ;
  MQGMO   GetMsgOpts = { MQGMO_DEFAULT };
  PMQGMO  pgmoin;
  PMQBYTE Buffer;
  MQLONG  BufferLength = BUFFERLENGTH;
  MQLONG  DataLength;

  /* variables for message formatting *****/
  int  ch;
  int  overrun;  /* used on MBCS characters */
  int  mbcsmax;  /* used for MBCS characters */
  int  char_len;  /* used for MBCS characters */
  char line_text[CHARS_PER_LINE + 4]; /* allows for up to 3 MBCS bytes overrun */
  int  chars_this_line = 0;
  int  lines_printed   = 0;
  int  page_number     = 1;

  /*                                       */
  /* Use a version 2 MQMD incase the       */
  /* message is Segmented/Grouped          */
  /*                                       */
  MsgDesc.Version = MQMD_VERSION_2 ;

  /*                                       */
  /* Initialise storage ....               */
  /*                                       */
  pmdin  = (PMQMD)malloc(sizeof(MQMD));
  pgmoin = (PMQGMO)malloc(sizeof(MQGMO));
  Buffer = (PMQBYTE)malloc(BUFFERLENGTH);

  /*                                       */
  /* determine locale for MBCS handling    */
  /*                                       */
  setlocale(LC_ALL,"");  /* for mbcs charactersets */
  mbcsmax = MB_CUR_MAX;  /* for mbcs charactersets */

  /*                                       */
  /* Handle the arguments passed           */
  /*                                       */
  printf("\nAMQSBCG0 - starts here\n");
  printf(  "**********************\n ");

  if (argc < 2)
  {
    printf("Required parameter missing - queue name\n");
    printf("\n  Usage: %s QName [ QMgrName ]\n",argv[0]);
    return 4 ;
  }

  /******************************************************************/
  /*                                                                */
  /*   Connect to queue manager                                     */
  /*                                                                */
  /******************************************************************/
  QMmgrName[0] =  '\0';                 /* set to null   default QM */
  if (argc > 2)
    strcpy(QMmgrName, argv[2]);

  strncpy(Queue,argv[1],MQ_Q_NAME_LENGTH);

  /*                                       */
  /* Start function here....               */
  /*                                       */
  MQCONN(QMmgrName,
         &Hconn,
         &CompCode,
         &Reason);

  if (CompCode != MQCC_OK)
  {
    printf("\n MQCONN failed with CompCode:%d, Reason:%d",
           CompCode,Reason);
    return (CompCode);
  }

  /*                                        */
  /* Set the options for the open call      */
  /*                                        */

  OpenOptions = MQOO_BROWSE;

  /*    @@@@ Use this for destructive read    */
  /*         instead of the above.            */
  /* OpenOptions = MQOO_INPUT_SHARED;         */
  /*                                          */

  strncpy(ObjDesc.ObjectName, Queue, MQ_Q_NAME_LENGTH);

  printf("\n MQOPEN - '%.*s'", MQ_Q_NAME_LENGTH,Queue);
  MQOPEN(Hconn,
         &ObjDesc,
         OpenOptions,
         &Hobj,
         &OpenCompCode,
         &Reason);

  if (OpenCompCode != MQCC_OK)
  {
    printf("\n MQOPEN failed with CompCode:%d, Reason:%d",
           OpenCompCode,Reason);

    printf("\n MQDISC");

    MQDISC(&Hconn,
           &CompCode,
           &Reason);

    if (CompCode != MQCC_OK)
    {
      printf("\n  failed with CompCode:%d, Reason:%d",
             CompCode,Reason);
    }

    return (OpenCompCode);
  }

  printf("\n ");

  /* Set the version number fot the Get Message Options */
  GetMsgOpts.Version = MQGMO_VERSION_2;

  /* Avoid need to reset Message ID and Correlation ID after */
  /* every MQGET                                             */
  GetMsgOpts.MatchOptions = MQMO_NONE;

  /* Set the options for the get calls         */
  GetMsgOpts.Options = MQGMO_NO_WAIT ;

  /* @@@@ Comment out the next line for          */
  /*      destructive read                       */

  GetMsgOpts.Options += MQGMO_BROWSE_NEXT ;

  /* Set the message descriptor and get message */
  /* options to the defaults                     */
  memcpy(pmdin, &MsgDesc, sizeof(MQMD) );
  memcpy(pgmoin, &GetMsgOpts, sizeof(MQGMO) );

  /*                                           */
  /* Loop until MQGET unsuccessful             */
  /*                                           */
  for (j = 1; CompCode == MQCC_OK; j++)
     {
     /*                                               */
     /* Set up the output format of the report        */
     /*                                               */
     if (page_number == 1)
     {
       lines_printed = 29;
       page_number = -1;
     }
     else
     {
       printf("\n ");
       lines_printed = 22;
     }

     /* Initialize the buffer to blanks               */
     memset(Buffer,' ',BUFFERLENGTH);

     MQGET(Hconn,
           Hobj,
           pmdin,
           pgmoin,
           BufferLength,
           Buffer,
           &DataLength,
           &CompCode,
           &Reason);

     if  (CompCode != MQCC_OK)
     {
       if (Reason != MQRC_NO_MSG_AVAILABLE)
       {
         printf("\n MQGET %d, failed with CompCode:%d Reason:%d",
                j,CompCode,Reason);
       }
       else
       {
         printf("\n \n \n No more messages ");
       }
     }
     else
     {
       /* Print the message             */
       /*                               */
       printf("\n ");
       printf("\n MQGET of message number %d ", j);
       /*                               */
       /* first the Message Descriptor  */
       printMD(pmdin);

       /*                               */
       /* then dump the Message         */
       /*                               */
       printf("\n ");
       printf("\n****   Message      ****\n ");
       Buffer[DataLength] = '\0';
       printf("\n length - %d bytes\n ", DataLength);
       ch = 0;
       overrun = 0;
       do
       {
         chars_this_line = 0;
         printf("\n%08X: ",ch);
         for (;overrun>0; overrun--) /* for MBCS overruns */
         {
           printf("  ");            /* dummy space for characters  */
           line_text[chars_this_line] = ' ';
                                /* included in previous line */
           chars_this_line++;
           if (overrun % 2)
             printf(" ");
         }
         while ( (chars_this_line < CHARS_PER_LINE) &&
                 (ch < DataLength) )
         {
           char_len = mblen((char *)&Buffer[ch],mbcsmax);
           if (char_len < 1)   /* badly formed mbcs character */
             char_len = 1;     /* or NULL treated as sbcs     */
           if (char_len > 1 )
           { /* mbcs case, assumes mbcs are all printable */
             for (;char_len >0;char_len--)
             {
               if ((chars_this_line % 2 == 0) &&
                   (chars_this_line < CHARS_PER_LINE))
                 printf(" ");
               printf("%02X",Buffer[ch] );
               line_text[chars_this_line] = Buffer[ch];
               chars_this_line++;
               ch++;
             }
           }
           else
           {  /* sbcs case */
             if (chars_this_line % 2 == 0)
               printf(" ");
             printf("%02X",Buffer[ch] );
             line_text[chars_this_line] =
                 isprint(Buffer[ch]) ? Buffer[ch] : '.';
             chars_this_line++;
             ch++;
           }
         }

         /* has an mbcs character overrun the usual end? */
         if (chars_this_line > CHARS_PER_LINE)
            overrun = chars_this_line - CHARS_PER_LINE;

         /* pad with blanks to format the last line correctly */
         if (chars_this_line < CHARS_PER_LINE)
         {
           for ( ;chars_this_line < CHARS_PER_LINE;
                chars_this_line++)
           {
             if (chars_this_line % 2 == 0) printf(" ");
             printf("  ");
             line_text[chars_this_line] = ' ';
           }
         }

         /* leave extra space between columns if MBCS characters possible */
         for (i=0;i < ((mbcsmax - overrun - 1) *2);i++)
         {
           printf(" "); /* prints space between hex representation and character */
         }

         line_text[chars_this_line] = '\0';
         printf(" '%s'",line_text);
         lines_printed += 1;
         if (lines_printed >= 60)
         {
           lines_printed = 0;
           printf("\n ");
         }
       }
       while (ch < DataLength);

     } /* end of message received 'else' */

  } /* end of for loop */

  printf("\n MQCLOSE");
  MQCLOSE(Hconn,
          &Hobj,
          MQCO_NONE,
          &CompCode,
          &Reason);

  if (CompCode != MQCC_OK)
  {
    printf("\n  failed with CompCode:%d, Reason:%d",
           CompCode,Reason);
    return (CompCode);
  }

  printf("\n MQDISC");
  MQDISC(&Hconn,
         &CompCode,
         &Reason);

  if (CompCode != MQCC_OK)
  {
    printf("\n  failed with CompCode:%d, Reason:%d",
           CompCode,Reason);
    return (CompCode);
  }

  return(0);
}

