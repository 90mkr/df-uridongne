// 기능 등록부 (본부 방만 고침)
// 기능 방이 새 기능을 만들면 본부 방에 「등록 요청」을 남기고, 본부 방이 여기에 한 줄 넣는다.
import '../core/feature.dart';
import '../core/remote.dart';
import 'alarm/feature.dart';
import 'anniv/feature.dart';
import 'board/feature.dart';
import 'bus/feature.dart';
import 'charger/feature.dart';
import 'deals/feature.dart';
import 'events/feature.dart';
import 'gas/feature.dart';
import 'lotto/feature.dart';
import 'parking/feature.dart';
import 'pharmacy/feature.dart';
import 'pet/feature.dart';
import 'phonebook/feature.dart';
import 'postcode/feature.dart';
import 'roulette/feature.dart';
import 'school/feature.dart';
import 'subway/feature.dart';
import 'toilet/feature.dart';
import 'trash/feature.dart';
import 'weather/feature.dart';

// 전체 기능 — 실제로 쓰는 목록은 아래 features (서버 app.json 「off」로 급히 숨긴 기능은 빠짐)
final List<Feature> allFeatures = [
  WeatherFeature(), // 머리 줄: 날씨·미세먼지
  TrashFeature(), // 맨 위: 오늘의 단지 소식
  BusFeature(), // 맨 아래 큰 카드: 단지 앞 버스
  RouletteFeature(), // 맨 아래 큰 카드: 오늘 뭐 먹지? 룰렛 (원판이 카드 밖으로)
  SubwayFeature(), // 맨 아래 큰 카드: 가까운 역 지하철 (시간표 기준)
  PharmacyFeature(), // 반쪽: 지금 문 연 약국
  PhonebookFeature(), // 묶음: 동네 전화번호부
  DealsFeature(), // 한 줄: 우리 단지 최근 거래
  ToiletFeature(), // 생활 도구 맨 앞: 가까운 화장실 (급할 때, 11-25)
  PetFeature(), // 생활 도구: 우리 동네 반려동물 (테마 — 안에 칸 목록, 반려동물 방이 대표님 허락으로 등록 11-26)
  GasFeature(), // 생활 도구
  ChargerFeature(),
  ParkingFeature(), // 생활 도구 + 홈: 가까운 공영주차장
  MyCarFeature(), // 생활 도구 + 홈: 내 차 어디 댔지 (주차장과 따로, 11-25)
  PostcodeFeature(),
  LottoFeature(),
  AnnivFeature(), // 생활 도구 + 홈 한 줄: 다가오는 기념일
  AlarmFeature(), // 생활 도구: 시계 앱 알람 넣기
  BoardFeature(), // 우리 단지 이야기 (소식·나눔·자유·업체 추천)
  EventsFeature(), // 생활 도구 + 홈 사진 카드: 주변 행사·축제 (주말엔 「지금 우리 단지」)
  SchoolFeature(), // 생활 도구 + 홈 한 줄(등록한 집만): 우리 아이 학교 급식·쉬는 날
];

List<Feature> get features => [for (final f in allFeatures) if (!remoteOff(f.id)) f];

Feature? featureById(String id) => features.where((f) => f.id == id).firstOrNull;
