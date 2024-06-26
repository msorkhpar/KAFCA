mkdir -p ESBM-eval
WORKING_DIR="$(pwd)/ESBM-eval"
ESBM_VERSION="v1.2"
ESBM_NAME="ESBM_benchmark_v1.2"
ESBM_EVAL_JAR_NAME="esummeval_v1.2.jar"
ARCHIVE_DIR="$WORKING_DIR/archive"
mkdir -p "$ARCHIVE_DIR"

function to_float() {
  echo "$1" | bc -l
}

function execute_and_move_the_result() {
  rm -rf ./KAFCA_lattice
  rm -rf ./KAFCA_result
  python3 fca_sumz.py
  rm -rf $WORKING_DIR/result
  mv ./KAFCA_result $WORKING_DIR/result
}

if [ ! -d "$WORKING_DIR/$ESBM_NAME" ]; then
  echo "Downloading ESBM benchmark dataset"
  curl https://codeload.github.com/nju-websoft/ESBM/tar.gz/master |
    tar -xz -C $WORKING_DIR --strip=2 ESBM-master/$ESBM_VERSION/$ESBM_NAME
fi

if [ ! -f "$WORKING_DIR/eval.jar" ]; then
  echo "Downloading ESBM esummeval jar file..."
  curl --request GET -sL \
    --url "https://raw.githubusercontent.com/nju-websoft/ESBM/master/$ESBM_VERSION/Evaluator/$ESBM_EVAL_JAR_NAME" \
    --output "$WORKING_DIR/eval.jar"
fi

echo "dbpedia_5, dbpedia_10, lmdb_5, lmdb_10" >F_measure.csv
echo "dbpedia_5, dbpedia_10, lmdb_5, lmdb_10" >NDCG.csv
for ((i = 1; i <= 10; i++)); do
  echo "Generating result of the current project [Round $i]"
  execute_and_move_the_result
  result=$(java -jar $WORKING_DIR/eval.jar $WORKING_DIR/$ESBM_NAME $WORKING_DIR/result |
    grep -Eo '\((dbpedia|lmdb)@\w+):\s+F-measure=([0-9.]+), NDCG=([0-9.]+)' |
    sed -E 's/\((dbpedia|lmdb)@(\w+)\):\s+F-measure=([0-9.]+), NDCG=([0-9.]+)/\1@\2,\3,\4/')
  while IFS=',' read -r key f_measure NDCG; do
    echo "$key, $f_measure, $NDCG"
    if [[ $key == "dbpedia@top5" ]]; then
      f_measure_dbpedia_5=$(to_float "$f_measure")
      ndcg_dbpedia_5=$(to_float "$NDCG")
    elif [[ $key == "dbpedia@top10" ]]; then
      f_measure_dbpedia_10=$(to_float "$f_measure")
      ndcg_dbpedia_10=$(to_float "$NDCG")
    elif [[ $key == "lmdb@top5" ]]; then
      f_measure_lmdb_5=$(to_float "$f_measure")
      ndcg_lmdb_5=$(to_float "$NDCG")
    elif [[ $key == "lmdb@top10" ]]; then
      f_measure_lmdb_10=$(to_float "$f_measure")
      ndcg_lmdb_10=$(to_float "$NDCG")
    fi
  done <<<"$result"
  echo "$f_measure_dbpedia_5, $f_measure_dbpedia_10, $f_measure_lmdb_5, $f_measure_lmdb_10" >>F_measure.csv
  echo "$ndcg_dbpedia_5, $ndcg_dbpedia_10, $ndcg_lmdb_5, $ndcg_lmdb_10" >>NDCG.csv
  cp -r "$WORKING_DIR/result" "$ARCHIVE_DIR/result_$i"


done
