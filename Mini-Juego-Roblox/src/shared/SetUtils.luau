--!strict
local Types = require(script.Parent.Types)

type Set<T> = Types.Set<T>
type Relation<A, B> = Types.Relation<A, B>

local SetUtils = {}

function SetUtils.New<T>(): Set<T>
	return {}
end

function SetUtils.FromList<T>(list: { T }): Set<T>
	local result: Set<T> = {}
	for _, item in ipairs(list) do
		result[item] = true
	end
	return result
end

function SetUtils.ToList<T>(set: Set<T>): { T }
	local result: { T } = {}
	for item, exists in pairs(set) do
		if exists then
			table.insert(result, item)
		end
	end
	return result
end

function SetUtils.Count<T>(set: Set<T>): number
	local count = 0
	for _, exists in pairs(set) do
		if exists then
			count += 1
		end
	end
	return count
end

function SetUtils.Contains<T>(set: Set<T>, item: T): boolean
	return set[item] == true
end

function SetUtils.Union<T>(A: Set<T>, B: Set<T>): Set<T>
	local result: Set<T> = {}
	for item, exists in pairs(A) do
		if exists then
			result[item] = true
		end
	end
	for item, exists in pairs(B) do
		if exists then
			result[item] = true
		end
	end
	return result
end

function SetUtils.Intersection<T>(A: Set<T>, B: Set<T>): Set<T>
	local result: Set<T> = {}
	for item, exists in pairs(A) do
		if exists and B[item] then
			result[item] = true
		end
	end
	return result
end

function SetUtils.Difference<T>(A: Set<T>, B: Set<T>): Set<T>
	local result: Set<T> = {}
	for item, exists in pairs(A) do
		if exists and not B[item] then
			result[item] = true
		end
	end
	return result
end

function SetUtils.IsSubset<T>(A: Set<T>, B: Set<T>): boolean
	for item, exists in pairs(A) do
		if exists and not B[item] then
			return false
		end
	end
	return true
end

function SetUtils.AreEqual<T>(A: Set<T>, B: Set<T>): boolean
	return SetUtils.IsSubset(A, B) and SetUtils.IsSubset(B, A)
end

function SetUtils.BitmaskCanCollide(layerA: number, maskA: number, layerB: number, maskB: number): boolean
	local aHitsB = bit32.band(layerA, maskB) ~= 0
	local bHitsA = bit32.band(layerB, maskA) ~= 0
	return aHitsB or bHitsA
end

function SetUtils.VerifyPartition<T>(universe: Set<T>, subsets: { Set<T> }): boolean
	local unionCover: Set<T> = {}

	for _, subset in ipairs(subsets) do
		for item, exists in pairs(subset) do
			if exists then
				-- Must belong to universe
				if not universe[item] then
					return false
				end
				-- Pairwise disjoint: cannot have been seen in prior subset
				if unionCover[item] then
					return false
				end
				unionCover[item] = true
			end
		end
	end

	-- Cover must equal universe
	for item, exists in pairs(universe) do
		if exists and not unionCover[item] then
			return false
		end
	end

	return true
end

return SetUtils
