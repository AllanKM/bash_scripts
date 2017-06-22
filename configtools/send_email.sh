#!/bin/bash
# Check for stdin
ZIPFILE=`date +'%Y%m%d'`.zip
function usage {
  echo "Usage:"
  echo ""
  echo "  $0 [-f] [attachment(s)] [-n] [attachment name ] [-s] [subject] [-m] [message] -t <recipient(s)>"
  echo ""
  echo "  -f Attachments, specify wildcards inside quotes. e.g. \"*.log\""
  echo "  -n Name of zip file which will appear in email, otherwise, date is used. e.g. 20100716.zip"
  echo "  -s Subject inside quotes. e.g. \"TPS Report\""
  echo "  -t Recipient email list, no spaces, comma-delimited"
  echo "  -m Message in quotes"
  echo ""
  exit 1
}
function process_recipient {
  TO=`echo $TO |sed -e 's|,| |g'` 
}
function process_file {
  FILE=`echo $FILE |sed -e 's|,| |g'` 
  for file in `echo $FILE`; do 
    if [ ! -f $file ]; then
      echo "Filename: \""$file"\" does not exist"
      exit 1
    fi
  done
  echo "Zipping files"
  zip -j $ZIPFILE $FILE 
  if [ $? -ne 0 ];then
    echo "File(s) not found or zip operation failed"
  fi
}

function send_email {
  SUBJECT=${SUBJECT:-`hostname`}
  if [ $opt_m ]; then
    MESSAGE="\n\n $MESSAGE"
  fi
  if [ $opt_f ]; then
    (uuencode $ZIPFILE $ZIPFILE; echo -e $MESSAGE)  | mail -s "$SUBJECT" $TO
  else
    echo "$MESSAGE" | mail -s "$SUBJECT" $TO 
  fi
}


while getopts "f:s:t:n:m:" opt; do
  case "$opt" in
    f ) FILE="$OPTARG"; opt_f=1 ;;
    s ) SUBJECT="$OPTARG"; opt_s=1 ;;
    t ) TO="$OPTARG"; opt_t=1 ;;
    n ) ZIPFILE="$OPTARG"; opt_t=1 ;;
    m ) MESSAGE="$OPTARG"; opt_m=1 ;;
    ? ) usage ;;
  esac
done
if [ -z $opt_t ]; then
  usage
  exit 1
fi
if [ $opt_f ]; then
  process_file 
fi
if [ $opt_t ]; then
  process_recipient 
fi
send_email 
if [ $opt_f ]; then
  rm $ZIPFILE
fi
