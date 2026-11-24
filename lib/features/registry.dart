// 기능 등록부 (본부 방만 고침)
// 기능 방이 새 기능을 만들면 본부 방에 「등록 요청」을 남기고, 본부 방이 여기에 한 줄 넣는다.
import '../core/feature.dart';
import 'bus/feature.dart';
import 'charger/feature.dart';
import 'deals/feature.dart';
import 'gas/feature.dart';
import 'lotto/feature.dart';
import 'parking/feature.dart';
import 'pharmacy/feature.dart';
import 'phonebook/feature.dart';
import 'postcode/feature.dart';
import 'subway/feature.dart';
import 'trash/feature.dart';
import 'weather/feature.dart';

final List<Feature> features = [
  WeatherFeature(), // 머리 줄: 날씨·미세먼지
  TrashFeature(), // 맨 위: 오늘의 단지 소식
  BusFeature(), // 맨 아래 큰 카드: 단지 앞 버스
  SubwayFeature(), // 맨 아래 큰 카드: 가까운 역 지하철 (시간표 기준)
  PharmacyFeature(), // 반쪽: 지금 문 연 약국
  PhonebookFeature(), // 묶음: 동네 전화번호부
  DealsFeature(), // 한 줄: 우리 단지 최근 거래
  GasFeature(), // 생활 도구
  ChargerFeature(),
  ParkingFeature(),
  PostcodeFeature(),
  LottoFeature(),
];

Feature? featureById(String id) => features.where((f) => f.id == id).firstOrNull;
