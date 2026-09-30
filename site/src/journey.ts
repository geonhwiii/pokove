import type { Lang } from './i18n';

/** A name in both languages. */
type Named = { ko: string; en: string };

export interface Stop {
  chapters: string;
  areas: Named;
  /** The gym leader at the end of these chapters; `badge` is PokéAPI's badge image number. */
  leader?: { name: Named; badge: number; level: number };
  /** The League's four, then its champion. */
  league?: { four: Named[]; champion: Named; level: number };
  /** A post-game boss (Johto's Red). */
  boss?: { name: Named; level: number };
  /** A legendary (or ★ spot) on a branch of these chapters. */
  legend?: { id: number; name: Named; level: number };
  /** Opens once the region has a Champion. */
  postgame?: boolean;
}

export interface JourneyRegion {
  id: 'kanto' | 'johto';
  name: Named;
  games: Named;
  starters: number[];
  stops: Stop[];
}

const n = (ko: string, en: string): Named => ({ ko, en });

/** The same journey the app plays (pokove/Adventure/Kanto.swift and Johto.swift), three chapters a stop. */
export const journey: JourneyRegion[] = [
  {
    id: 'kanto',
    name: n('관동', 'Kanto'),
    games: n('파이어레드·리프그린', 'FireRed & LeafGreen'),
    starters: [1, 4, 7],
    stops: [
      { chapters: '1–3', areas: n('1번도로 · 상록숲', 'Route 1 · Viridian Forest'), leader: { name: n('웅', 'Brock'), badge: 1, level: 14 } },
      { chapters: '4–6', areas: n('3번도로 · 달맞이산 · 24–25번도로', 'Route 3 · Mt. Moon · Routes 24–25'), leader: { name: n('이슬', 'Misty'), badge: 2, level: 21 } },
      { chapters: '7–9', areas: n('5–6번도로 · 디그다굴', "Routes 5–6 · Diglett's Cave"), leader: { name: n('마티스', 'Lt. Surge'), badge: 3, level: 24 } },
      { chapters: '10–12', areas: n('돌산터널 · 포켓몬타워 · 7–8번도로', 'Rock Tunnel · Pokémon Tower · Routes 7–8'), leader: { name: n('민화', 'Erika'), badge: 4, level: 29 } },
      {
        chapters: '13–15', areas: n('12–18번도로', 'Routes 12–18'), leader: { name: n('독수', 'Koga'), badge: 5, level: 43 },
        legend: { id: 143, name: n('잠만보', 'Snorlax'), level: 30 },
      },
      {
        chapters: '16–18', areas: n('사파리존', 'Safari Zone'), leader: { name: n('초련', 'Sabrina'), badge: 6, level: 43 },
        legend: { id: 145, name: n('썬더', 'Zapdos'), level: 50 },
      },
      {
        chapters: '19–21', areas: n('쌍둥이섬 · 포켓몬저택', 'Seafoam Islands · Pokémon Mansion'), leader: { name: n('강연', 'Blaine'), badge: 7, level: 47 },
        legend: { id: 144, name: n('프리져', 'Articuno'), level: 50 },
      },
      { chapters: '22–24', areas: n('21번수로 · 23번도로', 'Sea Route 21 · Route 23'), leader: { name: n('비주기', 'Giovanni'), badge: 8, level: 50 } },
      {
        chapters: '25–27', areas: n('챔피언로드', 'Victory Road'),
        league: { four: [n('칸나', 'Lorelei'), n('시바', 'Bruno'), n('국화', 'Agatha'), n('목호', 'Lance')], champion: n('그린', 'Blue'), level: 63 },
        legend: { id: 146, name: n('파이어', 'Moltres'), level: 50 },
      },
      { chapters: '28–30', areas: n('미지의동굴', 'Cerulean Cave'), legend: { id: 150, name: n('뮤츠', 'Mewtwo'), level: 70 }, postgame: true },
    ],
  },
  {
    id: 'johto',
    name: n('성도', 'Johto'),
    games: n('하트골드·소울실버', 'HeartGold & SoulSilver'),
    starters: [152, 155, 158],
    stops: [
      { chapters: '1–3', areas: n('29–31번도로 · 모다피의탑 · 어둠의동굴', 'Routes 29–31 · Sprout Tower · Dark Cave'), leader: { name: n('비상', 'Falkner'), badge: 9, level: 13 } },
      { chapters: '4–6', areas: n('32번도로 · 연결동굴 · 야돈의우물', 'Route 32 · Union Cave · Slowpoke Well'), leader: { name: n('호일', 'Bugsy'), badge: 10, level: 17 } },
      { chapters: '7–9', areas: n('너도밤나무숲 · 34번도로', 'Ilex Forest · Route 34'), leader: { name: n('꼭두', 'Whitney'), badge: 11, level: 19 } },
      {
        chapters: '10–12', areas: n('자연공원 · 35–37번도로 · 불탄탑', 'National Park · Routes 35–37 · Burned Tower'), leader: { name: n('유빈', 'Morty'), badge: 12, level: 25 },
        legend: { id: 185, name: n('꼬지모', 'Sudowoodo'), level: 20 },
      },
      {
        chapters: '13–15', areas: n('38–39번도로 · 40–41번수로 · 소용돌이섬', 'Routes 38–39 · Sea Routes 40–41 · Whirl Islands'), leader: { name: n('사도', 'Chuck'), badge: 13, level: 31 },
        legend: { id: 243, name: n('라이코', 'Raikou'), level: 40 },
      },
      {
        chapters: '16–18', areas: n('42번도로 · 험한산', 'Route 42 · Mt. Mortar'), leader: { name: n('규리', 'Jasmine'), badge: 14, level: 35 },
        legend: { id: 244, name: n('앤테이', 'Entei'), level: 40 },
      },
      {
        chapters: '19–21', areas: n('43번도로 · 분노의호수 · 44번도로', 'Route 43 · Lake of Rage · Route 44'), leader: { name: n('류옹', 'Pryce'), badge: 15, level: 34 },
        legend: { id: 130, name: n('빨간 갸라도스', 'Red Gyarados'), level: 30 },
      },
      {
        chapters: '22–24', areas: n('얼음추락길 · 용의굴 · 45–46번도로', "Ice Path · Dragon's Den · Routes 45–46"), leader: { name: n('이향', 'Clair'), badge: 16, level: 41 },
        legend: { id: 245, name: n('스이쿤', 'Suicune'), level: 40 },
      },
      {
        chapters: '25–27', areas: n('26–27번도로 · 챔피언로드', 'Routes 26–27 · Victory Road'),
        league: { four: [n('일목', 'Will'), n('독수', 'Koga'), n('시바', 'Bruno'), n('카렌', 'Karen')], champion: n('목호', 'Lance'), level: 50 },
        legend: { id: 249, name: n('루기아', 'Lugia'), level: 45 },
      },
      {
        chapters: '28–30', areas: n('은빛산', 'Mt. Silver'), boss: { name: n('레드', 'Red'), level: 88 },
        legend: { id: 250, name: n('칠색조', 'Ho-Oh'), level: 70 }, postgame: true,
      },
    ],
  },
];

export const say = (named: Named, lang: Lang) => named[lang];
