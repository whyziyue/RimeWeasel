local filter = {}

-- 初始化，加载配置和删除词条记录
function filter.init(env)
	local engine = env.engine
	local config = engine.schema.config
	env.word_reduce_idx = config:get_int("cold_word_reduce/idx") or 4

	-- 加载删词和隐藏词条的持久化记录
	env.drop_words = require("cold_word_drop.drop_words")
	env.hide_words = require("cold_word_drop.hide_words")
	env.reduce_freq_words = require("cold_word_drop.reduce_freq_words")

	-- 加载删除和隐藏的词条文件
	env.drop_words.load()  -- 从文件加载删除的词条
	env.hide_words.load()  -- 从文件加载隐藏的词条
end

-- 过滤候选词
function filter.func(input, env)
	local cands = {}
	local context = env.engine.context
	local preedit_str = context.input:gsub(" ", "")
	local drop_words = env.drop_words
	local hide_words = env.hide_words
	local word_reduce_idx = env.word_reduce_idx
	local reduce_freq_words = env.reduce_freq_words

	for cand in input:iter() do
		local cand_text = cand.text:gsub(" ", "")
		local preedit_code = cand.preedit:gsub(" ", "") or preedit_str

		local reduce_freq_list = reduce_freq_words[cand_text] or {}
		if word_reduce_idx > 1 then
			-- 前三个 候选项排除 要调整词频的词条, 已删除的词条 和 要隐藏的词条
			if reduce_freq_list and table.find_index(reduce_freq_list, preedit_code) then
				table.insert(cands, cand)
			elseif
				not (
					table.find_index(drop_words, cand_text)
					or (hide_words[cand_text] and table.find_index(hide_words[cand_text], preedit_code))

				)
			then
				yield(cand)
				word_reduce_idx = word_reduce_idx - 1
			end
		else
			if
				not (
					table.find_index(drop_words, cand_text)
					or (hide_words[cand_text] and table.find_index(hide_words[cand_text], preedit_code))
				)
			then
				table.insert(cands, cand)
			end
		end

		if #cands >= 180 then
			break
		end
	end

	for _, cand in ipairs(cands) do
		yield(cand)
	end
end

-- 删除词条并保存到文件
function filter.delete_word(cand_text)
	-- 添加到 drop_words 并持久化保存
	env.drop_words[cand_text] = true
	env.drop_words.save()  -- 保存到文件
end

return filter
