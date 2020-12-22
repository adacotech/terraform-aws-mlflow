# 適用したい環境を列挙する
ENVIRONMENTS = dev dev2 prod stg poc

# 自動生成ルール
NEWS    = $(addprefix new/, $(ENVIRONMENTS))
PLANS   = $(addprefix plan/, $(ENVIRONMENTS))
APPLIES = $(addprefix apply/, $(ENVIRONMENTS))


.PHONY: $(ENVIRONMENTS) $(PLANS) $(APPLIES)

# prefixなしのenv指定はapplyを呼び出す
$(foreach ENV, $(ENVIRONMENTS), $(eval $(ENV): apply/$(ENV)))

# workspaceの新規作成
$(NEWS):
	terraform workspace new $(@F)
	terraform init $(ARGS)

# plan、apply
$(PLANS) $(APPLIES):
	terraform workspace select $(@F)
	terraform $(@D) $(ARGS) -var-file terraform.$(@F).tfvars
