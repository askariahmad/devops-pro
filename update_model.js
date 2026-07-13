db.configurations.updateMany(
  { 'llmConfigs.modelName': 'qwen2.5-coder:0.5b' },
  { $set: { 'llmConfigs.$[elem].modelName': 'qwen2.5-coder:1.5b' } },
  { arrayFilters: [ { 'elem.modelName': 'qwen2.5-coder:0.5b' } ] }
);
print("Updated configurations!");
