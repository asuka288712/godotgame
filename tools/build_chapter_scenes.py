"""Generate editable greybox scenes, not runtime geometry. Run from repository root.
Do not rerun over art replacements: generated files are intentionally user editable.
"""
from pathlib import Path
import json

ROOT = Path('scenes/chapter')
ROOT.mkdir(parents=True, exist_ok=True)
def q(v): return json.dumps(v, ensure_ascii=False)
def vec(v): return 'Vector3(%s)' % ', '.join(str(x) for x in v)

class Scene:
    def __init__(self, name, location, indoor=False, color=(.34,.42,.36)):
        self.name=name; self.location=location; self.res=[]; self.nodes=[]; self.n=0
        self.ext=['[ext_resource type="Script" path="res://scripts/story/chapter_scene.gd" id="1"]', '[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="2"]', '[ext_resource type="Script" path="res://scripts/story/story_interaction.gd" id="3"]', '[ext_resource type="FontFile" path="res://assets/fonts/font.ttf" id="4"]', '[ext_resource type="Script" path="res://scripts/story/chapter_battle.gd" id="5"]', '[ext_resource type="Script" path="res://scripts/story/story_visual.gd" id="6"]']
        self.node(name,'Node3D',None,{'script':'ExtResource("1")','location_id':q(location)})
        self.node('World','Node3D','.')
        self.node('Architecture','Node3D','World')
        self.node('Props','Node3D','World')
        self.node('Interactions','Node3D','World')
        self.node('Spawns','Node3D','.')
        env=self.resource('Environment', 'background_mode = 1\nbackground_color = Color(0.18, 0.28, 0.33, 1)\nambient_light_source = 2\nambient_light_color = Color(0.82, 0.87, 0.91, 1)\nambient_light_energy = 0.75\ntonemap_mode = 2')
        self.node('Environment','WorldEnvironment','World',{'environment':env})
        self.node('Sun','DirectionalLight3D','World',{'rotation_degrees':vec((-52,-25,0)),'light_color':'Color(1, 0.91, 0.75, 1)','light_energy':'1.25','shadow_enabled':'true'})
        self.nodes.append('[node name="Player" parent="World" instance=ExtResource("2")]\nposition = Vector3(0, 0.15, 8)\nscale = Vector3(0.48, 0.48, 0.48)')
        self.node('Camera','Camera3D','.',{'position':vec((0,12,23)),'current':'true','projection':'1','size':'19','far':'160'})
        self.node('ChapterBattle','Node','.',{'script':'ExtResource("5")'})
        self.marker('entry',(0,.1,8))
        if location!='dock': self.box('Floor',(0,-.3,0),(32,.6,30),color,'World/Architecture')
        if indoor:
            self.box('RearWall',(0,1.8,-13),(32,3.6,.45),(.33,.24,.19),'World/Architecture')
            self.box('LeftWall',(-15.8,1.5,0),(.4,3,26),(.4,.29,.21),'World/Architecture')
            self.box('RightWall',(15.8,1.5,0),(.4,3,26),(.4,.29,.21),'World/Architecture')
            for x in [-12,-6,0,6,12]:
                self.box('Beam',(x,3.5,-12.6),(.4,.35,1),(.18,.14,.11),'World/Architecture')
        for pos,size in [((0,1,-15.5),(34,2,.4)),((0,1,15.5),(34,2,.4)),((-16.5,1,0),(.4,2,32)),((16.5,1,0),(.4,2,32))]:
            self.box('Boundary',pos,size,(0,0,0),'World/Architecture',visible=False)
    def resource(self,typ,body):
        self.n+=1; id='r%d'%self.n; self.res.append('[sub_resource type="%s" id="%s"]\n%s'%(typ,id,body));return 'SubResource("%s")'%id
    def node(self,name,typ,parent,props=None):
        hdr='[node name=%s type=%s'%(q(name),q(typ))
        if parent is not None: hdr+=' parent='+q(parent)
        self.nodes.append(hdr+']'+''.join('\n%s = %s'%(k,v) for k,v in (props or {}).items()))
    def material(self,color):
        return self.resource('StandardMaterial3D','albedo_color = Color(%s, 1)\nroughness = 0.88'%(', '.join(map(str,color))))
    def box(self,name,pos,size,color,parent='World/Props',solid=True,visible=True):
        self.n+=1; name=name+'_%d'%self.n; path=parent+'/'+name
        self.node(name,'StaticBody3D' if solid else 'Node3D',parent,{'position':vec(pos)})
        mesh=self.resource('BoxMesh','size = '+vec(size)+'\nmaterial = '+self.material(color))
        self.node('Visual','MeshInstance3D',path,{'mesh':mesh,'visible':str(visible).lower()})
        if solid:
            shape=self.resource('BoxShape3D','size = '+vec(size)); self.node('CollisionShape3D','CollisionShape3D',path,{'shape':shape})
        return path
    def marker(self,name,pos): self.node(name,'Marker3D','Spawns',{'position':vec(pos)})
    def sign(self,name,pos,text,parent='World/Props',size=40):
        self.node(name,'Label3D',parent,{'position':vec(pos),'text':q(text),'font':'ExtResource("4")','font_size':str(size),'pixel_size':'0.016','billboard':'1','outline_size':'8'})
    def point(self,id,title,pos,target='',spawn='entry',minimum=-1,maximum=99,idle='',person=False):
        path='World/Interactions/'+id
        self.node(id,'Node3D','World/Interactions',{'position':vec(pos),'script':'ExtResource("3")','interaction_id':q(id),'display_name':q(title),'target_location':q(target),'target_spawn':q(spawn),'minimum_stage':str(minimum),'maximum_stage':str(maximum),'idle_text':q(idle)})
        self.sign('NameLabel',(0,2.6,0),title,path,30)
        self.node('Visual','Node3D',path)
        if person:
            art = {
                'aunt': ('Texture2D', 'res://assets/sprite/npc/ldn.png'),
                'doctor': ('Texture2D', 'res://assets/sprite/npc/dys.png'),
                'vendor': ('Texture2D', 'res://assets/sprite/npc/dys.png'),
                'sailor': ('Texture2D', 'res://assets/sprite/npc/zsg.png'),
                'pond': ('PackedScene', 'res://scenes/zhao_linger.tscn'),
                'linger': ('PackedScene', 'res://scenes/zhao_linger.tscn'),
                'xianglan': ('PackedScene', 'res://scenes/npc.tscn'),
                'miao': ('PackedScene', 'res://scenes/enemies/死士.tscn'),
            }.get(id)
            if art:
                script_id = 'character_' + id
                art_id = 'art_' + id
                self.ext.append('[ext_resource type="Script" path="res://scripts/story/story_character.gd" id="%s"]' % script_id)
                self.ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (art[0], art[1], art_id))
                self.nodes[-1] += '\nscript = ExtResource("%s")\n%s = ExtResource("%s")\ncharacter_height = 1.9' % (script_id, 'character_scene' if art[0]=='PackedScene' else 'character_texture', art_id)
            else:
                mesh=self.resource('CapsuleMesh','radius = 0.35\nheight = 1.7\nmaterial = '+self.material((.44,.50,.57)))
                self.node('StandIn','MeshInstance3D',path+'/Visual',{'position':vec((0,.85,0)),'mesh':mesh})
        else:
            mesh=self.resource('CylinderMesh','top_radius = 0.65\nbottom_radius = 0.65\nheight = 0.06\nmaterial = '+self.material((.74,.62,.31)))
            self.node('Marker','MeshInstance3D',path+'/Visual',{'position':vec((0,.05,0)),'mesh':mesh})
        return path
    def tree(self,x,z):
        self.box('Trunk',(x,1,z),(.4,2,.4),(.29,.22,.15))
        mesh=self.resource('SphereMesh','radius = 1.5\nheight = 2.5\nmaterial = '+self.material((.28,.44,.32)))
        self.n+=1;self.node('Canopy%d'%self.n,'MeshInstance3D','World/Props',{'position':vec((x,2.8,z)),'mesh':mesh})
    def save(self,file):
        (ROOT/file).write_text('[gd_scene format=3]\n\n'+'\n\n'.join(self.ext+self.res+self.nodes)+'\n')

# Reusable guest room; visual and collisions are all native editable nodes.
s=Scene('InnGuestroom','guestroom',True,(.46,.34,.23))
s.box('Rug',(0,.035,1),(9,.05,8),(.35,.31,.4),solid=False)
for x in [-10,10]:
    s.box('BedFrame',(x,.45,-8),(3.4,.9,5.3),(.30,.19,.14));s.box('Bedding',(x,1,-8),(3.1,.2,4.7),(.68,.66,.51),solid=False)
    s.box('Pillow',(x,1.18,-9.8),(2,.25,.65),(.85,.79,.63),solid=False)
s.box('GuestTable',(-1,.6,-4),(3,1.2,2),(.39,.25,.17))
s.box('Wardrobe',(-13,1.3,3),(2,2.6,2),(.29,.22,.16))
s.point('miao','苗人住客 / 交谈',(-3,0,-1),maximum=11,person=True)
s.point('letter','行囊 / 查看家书',(10,0,2),minimum=15,idle='包袱里的信物已经收好。')
s.point('rest','床榻 / 歇息',(-9,0,-3))
s.point('exit','返回客栈',(0,0,12),'inn')
s.point('kitchen','前往厨房',(9,0,10),'kitchen')
s.sign('RoomTitle',(0,3.5,-12),'李家客栈 · 客房')
s.save('inn_guestroom.tscn')
# Extract the reusable room shell as a standalone PackedScene for future room variants.
base_nodes=[]
for node in s.nodes:
    if node.startswith('[node name="Architecture"'):
        base_nodes.append('[node name="InnRoomBase" type="Node3D"]')
    elif 'parent="World/Architecture' in node or 'parent="World/Props' in node:
        base_nodes.append(node.replace('parent="World/Architecture"','parent="."').replace('parent="World/Props"','parent="."').replace('parent="World/Architecture/','parent="').replace('parent="World/Props/','parent="'))
(ROOT/'inn_room_base.tscn').write_text('[gd_scene format=3]\n\n'+'\n\n'.join(s.ext[3:4]+s.res+base_nodes)+'\n')

s=Scene('InnKitchen','kitchen',True,(.38,.33,.25))
for x in [-10,-6,-2]:
    s.box('Stove',(x,.6,-8),(3,1.2,2.5),(.35,.36,.35));s.box('Pot',(x,1.5,-8),(1.1,.65,1.1),(.17,.20,.22),solid=False)
s.box('PrepCounter',(7,.7,-7),(8,1.4,2.8),(.50,.36,.22))
s.box('DiningTable',(0,.55,1),(4,1.1,2.6),(.40,.27,.17))
for x in [-12,-10,-8]:s.box('WineJar',(x,.6,5),(1.1,1.2,1.1),(.47,.30,.19))
s.point('aunt','李大娘 / 取酒与交谈',(5,0,-2),person=True)
s.point('wine','酒坛 / 取酒',(-9,0,7),maximum=0)
s.point('doctor','洪大夫',(10,0,-2),minimum=3,maximum=9,idle='救命的仙药不在寻常药铺。听说海上的仙灵岛有灵丹。',person=True)
s.point('rest','饭桌 / 用饭休息',(0,0,4))
s.point('exit','返回客栈',(0,0,12),'inn')
s.point('guestroom','前往客房',(9,0,10),'guestroom')
s.sign('KitchenTitle',(0,3,-12),'李家客栈 · 厨房')
s.save('inn_kitchen.tscn')

s=Scene('YuhangMarket','market',False,(.44,.43,.34))
s.box('StoneRoad',(0,.025,0),(6,.05,28),(.57,.55,.46),solid=False)
for x,z,c in [(-9,-7,(.53,.27,.20)),(9,-7,(.25,.40,.47)),(-9,2,(.52,.43,.24)),(9,2,(.36,.43,.29))]:
    s.box('StallCounter',(x,.6,z),(5,1.2,2.5),(.40,.29,.18))
    for dx in [-2.3,2.3]: s.box('StallPole',(x+dx,1.5,z),(.18,3,.18),(.31,.24,.17))
    s.box('Awning',(x,3,z),(5.5,.18,3),c,solid=False)
    for dx in [-1,0,1]:s.box('Goods',(x+dx,1.4,z),(.7,.4,.7),(.71,.58,.33),solid=False)
for x,z in [(-13,-12),(13,-12),(-13,10),(13,10)]:s.tree(x,z)
s.point('vendor','药摊 / 金创药 20文',(7,0,-3),idle='药贩在整理药材。',person=True)
s.point('beggar','醉道人',(-6,0,6),maximum=10,person=True,idle='醉道人惦记着客栈的好酒。')
s.point('xianglan','香兰',(-5,0,10),person=True,idle='李家哥哥，路上当心。婶婶和客人们的事都处理好了吗？')
s.point('fishmonger','鱼贩',(-7,0,-3),person=True,idle='海上有仙岛，也有风浪。要出海，去找码头的张四。')
s.point('inn','李家客栈',(0,0,12),'inn')
s.point('dock','出海码头',(12,0,6),'dock')
s.sign('MarketTitle',(0,4,-10),'余杭集市')
s.save('yuhang_market.tscn')

s=Scene('YuhangDock','dock',False)
s.box('Sea',(0,-.7,-6),(80,.4,70),(.19,.40,.48),solid=False)
s.box('Shore',(0,-.3,9),(32,.6,12),(.57,.53,.38),'World/Architecture')
s.box('Pier',(0,-.15,-5),(4,.3,20),(.43,.31,.20),'World/Architecture')
for x in [-2,2]:
    for z in range(-14,5,3):s.box('PierPost',(x,.45,z),(.28,.9,.28),(.26,.21,.15))
s.box('BoatHull',(5,-.05,-10),(4,.8,7),(.31,.23,.17),solid=False)
s.box('BoatCabin',(5,1,-9),(2.6,1.6,3.3),(.48,.36,.23),solid=False)
s.box('BoatMast',(5,3,-12),(.18,6,.18),(.36,.29,.19),solid=False)
s.box('Sail',(5,4,-12),(3,2.7,.12),(.86,.82,.68),solid=False)
for x,z in [(-8,8),(7,10),(10,8)]:s.box('Crate',(x,.6,z),(1.4,1.2,1.4),(.48,.35,.22))
s.marker('boat',(0,.1,-9))
s.point('sailor','张四 / 出海',(0,0,-12),person=True)
s.point('market','返回集市',(0,0,12),'market')
s.point('fisher','老渔翁',(-6,0,6),person=True,idle='去仙灵岛用小船，去苏州等客船。张四最熟这片水路。')
s.sign('DockTitle',(0,3,3),'余杭渡口 · 张四船行')
s.save('yuhang_dock.tscn')

s=Scene('XianlingIsland','island',False,(.38,.48,.35))
s.box('Ocean',(0,-.8,0),(90,.4,80),(.17,.43,.49),solid=False)
s.box('ShorePath',(0,.03,7),(8,.06,15),(.70,.66,.49),solid=False)
s.box('LotusPond',(7,.04,-8),(11,.08,7),(.25,.53,.55),solid=False)
s.box('Bridge',(3,.18,-4),(2,.3,6),(.60,.48,.31))
for x,z in [(-13,-11),(-13,-5),(-13,6),(13,4),(13,10),(-5,-12),(1,-12)]:s.tree(x,z)
for index,(x,z) in enumerate([(-8,6),(8,6),(-8,0),(8,0),(-8,-6),(0,-7)],1):
    point=s.point('statue_%d'%index,'石像 %d / 破阵'%index,(x,0,z))
    # Geometry is a child of Visual so replacements inherit the broken state.
    s.node('Stone','Node3D',point,{'script':'ExtResource("6")','statue_id':q('statue_%d'%index)})
    s.box('Idol',(0,.9,0),(1,1.8,1),(.54,.58,.55),point+'/Stone',solid=False)
s.marker('shore',(0,.1,10))
s.point('return_boat','小舟 / 返回余杭',(0,0,13))
s.point('pond','荷花池 / 赵灵儿',(7,0,-4),minimum=6,maximum=11,person=True,idle='灵儿望着水月宫的方向，似乎有话想说。')
s.point('palace_gate','水月宫',(0,0,-12))
s.point('herbs','药草 / 采集',(-12,0,10))
s.sign('IslandTitle',(0,4,-9),'仙灵岛 · 六像迷阵')
s.save('xianling_island.tscn')

s=Scene('ShuiyuePalace','palace',False,(.49,.56,.50))
s.box('Courtyard',(0,.035,1),(23,.07,18),(.70,.72,.62),solid=False)
s.box('BackWall',(0,2,-12),(24,4,.45),(.56,.65,.62),'World/Architecture')
for x in [-10,-5,5,10]:s.box('JadePillar',(x,2,-8),(.6,4,.6),(.47,.61,.58))
s.box('PalaceRoof',(0,4.2,-10),(26,.45,6),(.25,.39,.41),solid=False)
s.box('RestingCouch',(-7,.45,-6),(4,.9,3),(.56,.42,.35))
s.box('Altar',(5,.65,-6),(3,1.3,2),(.55,.40,.26))
s.node('RuinBeam','Node3D','World/Props',{'position':vec((1,0,-6)),'script':'ExtResource("6")','broken_after_stage':'12'})
s.box('DamagedBeam',(0,2.4,0),(.45,4.8,.45),(.35,.32,.26),'World/Props/RuinBeam',solid=False)
for x,z in [(-13,5),(13,5),(12,-10)]:s.tree(x,z)
s.point('elder','姥姥',(-6,0,-2),maximum=13,person=True,idle='姥姥静静休息着。')
s.point('night','喜烛 / 歇息',(5,0,-3),minimum=8,maximum=9)
s.point('linger','赵灵儿',(0,0,-2),minimum=7,maximum=11,person=True,idle='无论将来走到哪里，都不要忘了今日的约定。')
s.point('burial','后院 / 安葬姥姥',(11,0,-7),minimum=13,idle='姥姥长眠于此。灵儿默默行礼。')
s.point('island','返回仙灵岛',(0,0,12),'island')
s.sign('PalaceTitle',(0,4,-10),'水月宫')
s.save('shuiyue_palace.tscn')

s=Scene('MountainTemple','temple',False,(.35,.41,.31))
s.box('StonePath',(0,.03,1),(5,.06,25),(.53,.54,.46),solid=False)
s.box('TempleWall',(0,1.5,-9),(12,3,.4),(.45,.39,.30),'World/Architecture')
s.box('TempleRoof',(0,3.2,-9),(14,.4,5),(.25,.31,.32),solid=False)
s.box('Altar',(0,.55,-7),(3,1.1,1.8),(.51,.41,.30))
for x,z in [(-11,-9),(11,-9),(-10,0),(10,0),(-12,10),(12,10)]:s.tree(x,z)
s.point('sword','酒剑仙 / 赴约',(-3,0,-3),minimum=10,person=True,idle='剑招记住了，更要记住行走江湖的分寸。')
s.point('practice','练剑石',(5,0,0),idle='石上留着剑痕。待学成剑术，可在战斗的技能菜单中使用御剑术。')
s.point('rest','石凳 / 调息',(-5,0,5))
s.point('market','下山返回渔村森林',(0,0,12),'town',spawn='forest_return')
s.sign('TempleTitle',(0,4,-9),'十里坡 · 山神庙')
s.save('mountain_temple.tscn')
print('Wrote seven playable scenes and reusable inn_room_base.tscn')
