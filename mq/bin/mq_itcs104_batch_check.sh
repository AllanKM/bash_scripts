#!/bin/ksh

  CMD=/tmp/mq_itcs104_check.sh
  echo "  /lfs/system/tools/mq/bin/mq_itcs104.sh" > $CMD
  chmod u+x $CMD

# /lfs/system/tools/mq/bin/mq_batch_tiv.pl -w /fs/system/audit/mqm -c $CMD -s -o role==mq*.* role==wbimb*
  /lfs/system/tools/mq/bin/mq_batch_tiv.pl -w /fs/system/audit/mqm -c $CMD -s -o role==mq*.* role==wbimb*.broker.* role==wbimb*.manager.*
