#!/bin/bash
source ./test_tipc/common_func.sh
FILENAME=$1
dataline=$(cat ${FILENAME})
# parser params
IFS=$'\n'
lines=(${dataline})
IFS=$'\n'
lite_model_list=$(func_parser_value "${lines[2]}")

# prepare lite .nb model
pip install paddlelite==2.9
current_dir=${PWD}
IFS="|"
model_path=./inference_models
for model in ${lite_model_list[*]}; do
    inference_model_url=https://paddleocr.bj.bcebos.com/PP-OCRv2/chinese/${model}.tar
    inference_model=${inference_model_url##*/}
    wget -nc  -P ${model_path} ${inference_model_url}
    cd ${model_path} && tar -xf ${inference_model} && cd ../
    model_dir=${model_path}/${inference_model%.*}
    model_file=${model_dir}/inference.pdmodel
    param_file=${model_dir}/inference.pdiparams
    paddle_lite_opt --model_dir=${model_dir} --model_file=${model_file} --param_file=${param_file} --valid_targets=arm --optimize_out=${model_dir}_opt
done

# prepare test data
data_url=https://paddleocr.bj.bcebos.com/dygraph_v2.0/test/icdar2015_lite.tar
model_path=./inference_models
inference_model=${inference_model_url##*/}
data_file=${data_url##*/}
wget -nc  -P ./inference_models ${inference_model_url}
wget -nc  -P ./test_data ${data_url}
cd ./inference_models && tar -xf ${inference_model} && cd ../
cd ./test_data && tar -xf ${data_file} && rm ${data_file} && cd ../

# prepare lite env
paddlelite_url=https://github.com/PaddlePaddle/Paddle-Lite/releases/download/v2.9/inference_lite_lib.android.armv8.gcc.c++_shared.with_extra.with_cv.tar.gz
paddlelite_zipfile=$(echo $paddlelite_url | awk -F "/" '{print $NF}')
paddlelite_file=${paddlelite_zipfile:0:66}
wget ${paddlelite_url} && tar -xf ${paddlelite_zipfile}
mkdir -p  ${paddlelite_file}/demo/cxx/ocr/test_lite
cp -r ${model_path}/*_opt.nb test_data ${paddlelite_file}/demo/cxx/ocr/test_lite
cp ppocr/utils/ppocr_keys_v1.txt deploy/lite/config.txt ${paddlelite_file}/demo/cxx/ocr/test_lite
cp -r ./deploy/lite/* ${paddlelite_file}/demo/cxx/ocr/
cp ${paddlelite_file}/cxx/lib/libpaddle_light_api_shared.so ${paddlelite_file}/demo/cxx/ocr/test_lite
cp ${FILENAME} test_tipc/test_lite_arm_cpu_cpp.sh test_tipc/common_func.sh ${paddlelite_file}/demo/cxx/ocr/test_lite
cd ${paddlelite_file}/demo/cxx/ocr/
git clone https://github.com/cuicheng01/AutoLog.git
make -j
sleep 1
make -j
cp ocr_db_crnn test_lite && cp test_lite/libpaddle_light_api_shared.so test_lite/libc++_shared.so
tar -cf test_lite.tar ./test_lite && cp test_lite.tar ${current_dir} && cd ${current_dir}
rm -rf ${paddlelite_file}* && rm -rf ${model_path}
