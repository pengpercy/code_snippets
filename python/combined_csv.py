import os
import pandas as pd

# 指定目标目录
directory = './source/'  # 修改为你的目标目录路径

# 获取目标目录中的所有 csv 文件
csv_files = [file for file in os.listdir(directory) if file.endswith('.csv')]

# 初始化一个空的 DataFrame
combined_df = pd.DataFrame()

# 读取每个 csv 文件并合并到一个 DataFrame 中
for csv_file in csv_files:
    file_path = os.path.join(directory, csv_file)
    df = pd.read_csv(file_path)
    combined_df = pd.concat([combined_df, df], ignore_index=True)

# 去除重复行
combined_df.drop_duplicates(inplace=True)

# 保存合并后的数据到一个新的 csv 文件
output_path = os.path.join(directory, './../../csv/ASIAIP.csv')
combined_df.to_csv(output_path, index=False)

print(f'所有CSV文件已合并并去重，结果保存在 {output_path} 中。')
